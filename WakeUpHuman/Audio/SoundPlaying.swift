/// A generated sound the app can start and stop. Real implementations wrap `AVAudioEngine`;
/// tests use a fake. The alarm tone (here) and the rain (#16) conform.
@MainActor
protocol SoundPlaying: AnyObject {
    var isPlaying: Bool { get }
    func start() throws
    func stop()
}
