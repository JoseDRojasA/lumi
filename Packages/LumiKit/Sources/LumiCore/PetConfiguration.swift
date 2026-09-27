public struct PetConfiguration: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var generatorVersion: Int
    public var seed: UInt64
    public var body: BodyTraits
    public var palette: Palette
    public var face: FaceTraits
    public var ears: EarTraits
    public var tail: TailTraits
    public var details: DetailTraits
    public var motionPersonality: MotionPersonality

    public init(
        formatVersion: Int,
        generatorVersion: Int,
        seed: UInt64,
        body: BodyTraits,
        palette: Palette,
        face: FaceTraits,
        ears: EarTraits,
        tail: TailTraits,
        details: DetailTraits,
        motionPersonality: MotionPersonality
    ) {
        self.formatVersion = formatVersion
        self.generatorVersion = generatorVersion
        self.seed = seed
        self.body = body
        self.palette = palette
        self.face = face
        self.ears = ears
        self.tail = tail
        self.details = details
        self.motionPersonality = motionPersonality
    }
}
