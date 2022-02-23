using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class AuthenticatedPeerChallenge {

        public const int CHALLENGE_LENGTH = 256;

        public AuthenticatedPeerIdentity identity { get; private set; }
        public uint8[] challenge_data { get; private set; }

        public uint8[] serialise() {
            return new ByteComposer()
                .add_byte_array(challenge_data)
                .add_byte_array(identity.serialise())
                .to_byte_array();
        }

        public AuthenticatedPeerChallenge.from_data(uint8[] data) throws Error {
            challenge_data = data[0:CHALLENGE_LENGTH];
            identity = new AuthenticatedPeerIdentity.deserialise(data[CHALLENGE_LENGTH:data.length -1]);
        }

        public AuthenticatedPeerChallenge(AuthenticatedPeerIdentity for_peer) {
            identity = for_peer;
            challenge_data = new uint8[CHALLENGE_LENGTH];
            Sodium.Random.random_bytes(challenge_data);
        }

    }


}