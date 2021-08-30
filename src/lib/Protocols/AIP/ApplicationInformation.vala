using LibPeer.Protocols.Mx2;
using Gee;

namespace LibPeer.Protocols.Aip {

    public class ApplicationInformation {

        public InstanceReference instance { get; protected set; }

        public string application_namespace { get; protected set; }

        public Bytes namespace_bytes { owned get {
            return new Bytes(((uint8[])application_namespace)[0:-2]);
        }}

        public HashSet<Bytes> resource_set = new Gee.HashSet<Bytes>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        public ApplicationInformation(InstanceReference iref, string app_namespace) {
            instance = iref;
            application_namespace = app_namespace;
        }
    }

}