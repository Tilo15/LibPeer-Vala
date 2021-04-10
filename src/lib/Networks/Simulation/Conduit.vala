using LibPeer.Networks;

using Gee;

namespace LibPeer.Networks.Simulation {

    public class Conduit {

        private HashMap<Bytes, NetSim> interfaces = new HashMap<Bytes, NetSim>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        private int count = 0;

        public NetSim get_interface(int delay = 0, int latency = 100, float loss_frac = 0.0f) {
            count ++;

            // Generate the UUID for this interface
            uint8[] identifier = new uint8[16];
            UUID.generate_random(identifier);

            // Create the interface
            NetSim iface = new NetSim(this, identifier, count, delay, latency, loss_frac);

            // Add interface to map
            interfaces.set(iface.identifier, iface);

            // Return the interface
            return iface;
        }

        internal void send_packet(Bytes origin, Bytes destination, Bytes data) {
            // Do we have the destination?
            if (!interfaces.has_key(destination)) {
                // No, skip
                return;
            }

            // Get the destination interface
            NetSim dest_iface = interfaces.get(destination);

            // Pass on the packet
            dest_iface.receive_data(origin, data);
        }

        internal void advertise(Bytes origin, Advertisement advertisement) {
            foreach (var iface in interfaces) {
                // Don't advertise to the origin
                if (iface.key.compare(origin) != 0) {
                    iface.value.receive_advertisment(advertisement);
                }
            }
        }

    }
}