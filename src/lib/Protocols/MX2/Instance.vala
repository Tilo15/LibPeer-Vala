using Sodium;
using Gee;

namespace LibPeer.Protocols.Mx2 {

    public class Instance {

        public string application_namespace { get ; protected set; }

        public uint8[] seal_public_key { get; protected set; }
        public uint8[] seal_private_key { get; protected set; }

        public uint8[] sign_public_key { get; protected set; }
        public uint8[] sign_private_key { get; protected set; }

        public HashSet<InstanceReference> reachable_peers { get; default = new HashSet<InstanceReference>((m) => m.hash(), (a, b) => a.compare(b) == 0); }

        public signal void incoming_payload(Packet packet);
        public signal void incoming_greeting(InstanceReference origin);

        public InstanceReference reference {
            owned get {
                return new InstanceReference(sign_public_key, seal_public_key);
            }
        }

        public Instance(string app_namespace) {
            application_namespace = app_namespace;

            seal_private_key = new uint8[Asymmetric.Sealing.SECRET_KEY_BYTES];
            seal_public_key = new uint8[Asymmetric.Sealing.PUBLIC_KEY_BYTES];
            Asymmetric.Sealing.generate_keypair(seal_public_key, seal_private_key);

            sign_private_key = new uint8[Asymmetric.Signing.SECRET_KEY_BYTES];
            sign_public_key = new uint8[Asymmetric.Signing.PUBLIC_KEY_BYTES];
            Asymmetric.Signing.generate_keypair(sign_public_key, sign_private_key);


        }

    }

}