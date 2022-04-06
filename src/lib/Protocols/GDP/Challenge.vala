using Sodium.Asymmetric;


namespace LibPeer.Protocols.Gdp {

    public class Challenge {

        public delegate uint8[] ChallengeGenerator(uint8[] secret);

        public uint8[] public_key { get; set; }

        public uint8[] challenge_blob { get; set; }

        private uint8[]? secret { get; set; }

        public bool solved {
            get{
                return secret != null;
            }
        }

        public bool complete(uint8[] secret) {
            var signed = Signing.sign(public_key, secret);
            if(Signing.verify(signed, public_key) != null) {
                this.secret = secret;
                return true;
            }
            return false;
        }

        internal uint8[] sign(uint8[] message) requires (solved) {
            return Signing.sign(message, secret);
        }

        public bool check_key(uint8[] compare) {
            return new Bytes(compare).compare(new Bytes(public_key)) == 0;
        }

        public Challenge(ChallengeGenerator generator) {
            public_key = new uint8[Signing.PUBLIC_KEY_BYTES];
            var sk = new uint8[Signing.SECRET_KEY_BYTES];
            Signing.generate_keypair(public_key, sk);
            challenge_blob = generator(sk);
        }

        public Challenge.from_values(uint8[] key, uint8[] challenge) {
            public_key = key;
            challenge_blob = challenge;
        }

    }

}