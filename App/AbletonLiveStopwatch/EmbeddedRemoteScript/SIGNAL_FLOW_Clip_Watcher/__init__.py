from .signal_flow_clip_watcher import SignalFlowClipWatcher


def create_instance(c_instance):
    return SignalFlowClipWatcher(c_instance)
