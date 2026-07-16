from .live_stopwatch_clip_watcher import LiveStopwatchClipWatcher


def create_instance(c_instance):
    return LiveStopwatchClipWatcher(c_instance)
