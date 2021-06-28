
namespace LibPeer.Protocols.Mx2 {

    public class Packet {

        public InstanceReference origin { get ; protected set; }

        public InstanceReference destination { get ; protected set; }

        public InputStream stream { get; protected set; }

        public Packet(InstanceReference origin, InstanceReference destination, InputStream stream) {
            this.origin = origin;
            this.destination = destination;
            this.stream = stream;
        }
    }

}