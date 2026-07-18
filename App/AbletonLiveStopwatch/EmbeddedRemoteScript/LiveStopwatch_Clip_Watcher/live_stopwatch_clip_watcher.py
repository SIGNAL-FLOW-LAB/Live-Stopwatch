# Ableton Live Remote Script
# Live Stopwatch Clip Watcher v3.1.0

import json
import socket
import time

from _Framework.ControlSurface import ControlSurface


UDP_HOST = "127.0.0.1"
UDP_PORT = 45722
PLAYBACK_TRACK_INDEX = 0
POLL_INTERVAL_TICKS = 2
INITIAL_SCENE_ONLY_SECONDS = 3.0


class LiveStopwatchClipWatcher(ControlSurface):
    def __init__(self, c_instance):
        super().__init__(c_instance)

        self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._playback_track = None
        self._last_playing_scene = None
        self._last_selected_signature = None
        self._initial_highlight_signature = None
        self._highlight_has_changed = False
        self._started_at = time.time()

        with self.component_guard():
            self._attach_playback_track()
            self._attach_transport_listener()

            self._send({
                "type": "hello",
                "version": "3.1.0",
            })

            self.schedule_message(
                POLL_INTERVAL_TICKS,
                self._poll_selected_item,
            )

    def _attach_playback_track(self):
        tracks = list(self.song().tracks)

        if len(tracks) <= PLAYBACK_TRACK_INDEX:
            self.log_message(
                "Live Stopwatch: playback Track 1 not found"
            )
            return

        self._playback_track = tracks[PLAYBACK_TRACK_INDEX]
        self._last_playing_scene = int(
            self._playback_track.playing_slot_index
        )

        if not self._playback_track.playing_slot_index_has_listener(
            self._on_playing_slot_changed
        ):
            self._playback_track.add_playing_slot_index_listener(
                self._on_playing_slot_changed
            )

        if self._last_playing_scene >= 0:
            self._send_scene_change(self._last_playing_scene)

    def _attach_transport_listener(self):
        if not self.song().is_playing_has_listener(
            self._on_transport_changed
        ):
            self.song().add_is_playing_listener(
                self._on_transport_changed
            )

    def _on_transport_changed(self):
        if self.song().is_playing:
            self._send({"type": "transport_start"})
        else:
            self._send({"type": "transport_stop"})

    def _on_playing_slot_changed(self):
        if self._playback_track is None:
            return

        scene_index = int(
            self._playback_track.playing_slot_index
        )

        if scene_index == self._last_playing_scene:
            return

        self._last_playing_scene = scene_index

        if scene_index >= 0:
            self._send_scene_change(scene_index)
        else:
            self._send({"type": "scene_stop"})

    def _send_scene_change(self, scene_index):
        self._send({
            "type": "scene_change",
            "scene_index": scene_index,
            "scene_name": self._scene_name(scene_index),
        })

    def _scene_name(self, scene_index):
        scenes = list(self.song().scenes)

        if scene_index < 0 or scene_index >= len(scenes):
            return "—"

        return scenes[scene_index].name or "名称未設定"

    def _poll_selected_item(self):
        try:
            payload = self._selected_item_payload()

            signature = (
                payload.get("scene_index", -1),
                payload.get("track_index", -1),
                payload.get("display_name", "—"),
                payload.get("source", "scene"),
            )

            if signature != self._last_selected_signature:
                self._last_selected_signature = signature
                self._send(payload)

        except Exception as error:
            self.log_message(
                "Live Stopwatch selection error: {}".format(error)
            )

        self.schedule_message(
            POLL_INTERVAL_TICKS,
            self._poll_selected_item,
        )

    def _selected_item_payload(self):
        tracks = list(self.song().tracks)
        scenes = list(self.song().scenes)

        selected_scene = self.song().view.selected_scene
        selected_track = self.song().view.selected_track
        highlighted_slot = self.song().view.highlighted_clip_slot

        scene_index = -1
        track_index = -1
        highlighted_track_index = -1
        highlighted_scene_index = -1
        display_name = "—"
        source = "scene"

        try:
            scene_index = scenes.index(selected_scene)
        except ValueError:
            pass

        try:
            track_index = tracks.index(selected_track)
        except ValueError:
            track_index = -1

        if highlighted_slot is not None:
            for candidate_track_index, track in enumerate(tracks):
                for candidate_scene_index, slot in enumerate(track.clip_slots):
                    if slot == highlighted_slot:
                        highlighted_track_index = candidate_track_index
                        highlighted_scene_index = candidate_scene_index
                        break

                if highlighted_scene_index >= 0:
                    break

        highlight_signature = (
            highlighted_track_index,
            highlighted_scene_index,
        )

        if self._initial_highlight_signature is None:
            self._initial_highlight_signature = highlight_signature
        elif highlight_signature != self._initial_highlight_signature:
            self._highlight_has_changed = True

        # 起動後3秒間は、Liveが保持している古いTrack 1選択を
        # 完全に無視してScene名だけを返します。
        startup_guard_active = (
            time.time() - self._started_at
            < INITIAL_SCENE_ONLY_SECONDS
        )

        if (
            not startup_guard_active
            and self._highlight_has_changed
            and track_index >= 0
            and scene_index >= 0
            and highlighted_track_index == track_index
            and highlighted_scene_index == scene_index
            and scene_index < len(selected_track.clip_slots)
        ):
            selected_slot = selected_track.clip_slots[scene_index]

            if selected_slot.has_clip and selected_slot.clip is not None:
                display_name = (
                    selected_slot.clip.name
                    or "名称未設定"
                )
                source = "clip"

        if display_name == "—" and scene_index >= 0:
            display_name = self._scene_name(scene_index)
            source = "scene"

        return {
            "type": "selected_item",
            "scene_index": scene_index,
            "track_index": track_index,
            "display_name": display_name,
            "source": source,
        }

    def _send(self, payload):
        try:
            data = json.dumps(
                payload,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")

            self._socket.sendto(
                data,
                (UDP_HOST, UDP_PORT),
            )

        except Exception as error:
            self.log_message(
                "Live Stopwatch UDP error: {}".format(error)
            )

    def disconnect(self):
        try:
            if (
                self._playback_track is not None
                and self._playback_track.playing_slot_index_has_listener(
                    self._on_playing_slot_changed
                )
            ):
                self._playback_track.remove_playing_slot_index_listener(
                    self._on_playing_slot_changed
                )
        except Exception:
            pass

        try:
            if self.song().is_playing_has_listener(
                self._on_transport_changed
            ):
                self.song().remove_is_playing_listener(
                    self._on_transport_changed
                )
        except Exception:
            pass

        try:
            self._socket.close()
        except Exception:
            pass

        super().disconnect()
