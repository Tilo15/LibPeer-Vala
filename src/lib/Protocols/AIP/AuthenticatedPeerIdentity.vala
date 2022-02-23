using Sodium.Asymmetric;
using LibPeer.Util;

namespace LibPeer.Protocols.Aip {

    public class AuthenticatedPeerIdentity {

        internal uint8[] public_key { get; private set; }

        internal uint8[] verify(uint8[] data) {
            return Signing.verify(data, public_key);
        }

        public uint8[] serialise() {
            return public_key.copy();
        }

        public AuthenticatedPeerIdentity.deserialise(uint8[] data) requires (data.length == Signing.PUBLIC_KEY_BYTES) {
            public_key = data;
        }

        public bool equals(AuthenticatedPeerIdentity other) {
            return new Bytes(public_key).compare(new Bytes(other.public_key)) == 0;
        }

    }


}