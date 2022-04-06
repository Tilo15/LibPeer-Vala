using LibPeer.Protocols.Mx2;

namespace LibPeer.Protocols.Gdp {

    public class GdpApplication {
        
        public string app_namespace { get; private set; }

        public InstanceReference instance_reference { get; private set; }

        private uint8[] namespace_secret_hash;

        public uint8[] namespace_hash { get; private set; }

        public signal void challenged(Bytes resource_hash, Challenge challenge);

        public signal void query_answered(Answer answer);

        public bool solve_app_challenge(Challenge challenge) {
            return challenge.complete(xor_with_secret_hash(challenge.challenge_blob));
        }

        public Challenge create_app_challenge() {
            return new Challenge(xor_with_secret_hash);
        }

        private uint8[] xor_with_secret_hash(uint8[] data) {
            var output = new uint8[data.length];
            for(var i = 0; i < data.length; i++) {
                output[i] = data[i] ^ namespace_secret_hash[i];
            }
            return output;
        }

        public GdpApplication(string name, InstanceReference instance) {
            app_namespace = name;
            instance_reference = instance;

            var checksum = new Checksum(ChecksumType.SHA512);
            checksum.update((uchar[])app_namespace, app_namespace.length);
            namespace_secret_hash = new uint8[ChecksumType.SHA512.get_length()];
            size_t size = namespace_secret_hash.length;
            checksum.get_digest(namespace_secret_hash, ref size);

            checksum = new Checksum(ChecksumType.SHA256);
            checksum.update(namespace_secret_hash, namespace_secret_hash.length);
            namespace_hash = new uint8[ChecksumType.SHA256.get_length()];
            size = namespace_hash.length;
            checksum.get_digest(namespace_hash, ref size);
        }

    }

}