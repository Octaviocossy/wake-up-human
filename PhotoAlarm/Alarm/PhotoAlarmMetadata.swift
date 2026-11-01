import AlarmKit

/// The metadata AlarmKit stores with every System alarm. Empty on purpose: the app keeps its own
/// state in its container. Named `PhotoAlarmMetadata` because `AlarmMetadata` is AlarmKit's protocol.
nonisolated struct PhotoAlarmMetadata: AlarmMetadata {}
