using LibPeer.Networks;
using LibPeer.Protocols.Mx2;
using LibPeer.Util;

namespace LibPeer.Networks.Simulation {

    public class NetSim : Network {

        private Conduit conduit;
        private int count;
        public Bytes identifier;
        public int delay;
        public int latency;
        public float loss_frac;
        private bool up = false;
        private AsyncQueue<QueueCommand<Packet>> packet_queue = new AsyncQueue<QueueCommand<Packet>>();
        private Thread<bool> worker_thread;

        public NetSim(Conduit conduit, uint8[] uuid, int count, int delay, int latency, float loss_frac) {
            this.conduit = conduit;
            this.count = count;
            this.identifier = new Bytes(uuid);
            this.delay = delay;
            this.latency = latency;
            this.loss_frac = loss_frac;
        }

        public override GLib.Bytes get_network_identifier () {
            return new Bytes({'N', 'e', 't', 'S', 'i', 'm'});
        }

        public override uint16 get_mtu() {
            return uint16.MAX;
        }
    
        public override void bring_up() throws IOError, Error {
            if (up) {
                return;
            }

            up = true;
            ThreadFunc<bool> queue_worker = () => {
                while (true) {
                    QueueCommand<Packet> command = packet_queue.pop();
                    if(command.command == QueueControl.Stop) {
                        return true;
                    }

                    assert(command.command == QueueControl.Payload);

                    // Delay
                    Posix.usleep(delay * 1000);

                    // Drop
                    if (Random.int_range(1, 100) == loss_frac * 100) {
                        print("[NET] Drop!\n");
                        continue;
                    }

                    // Create a stream
                    var stream = new MemoryInputStream.from_bytes(command.payload.data);

                    // Create ane emit receiption
                    var receiption = new Receiption(stream, command.payload.peer_info, this);
                    incoming_receiption(receiption);
                }
            };

            worker_thread = new Thread<bool>(@"NetSim-iface-$(count)", queue_worker);
        }
    
        public override void bring_down() throws IOError, Error {
            if(!up) {
                return;
            }

            up = false;
            this.packet_queue.push_front(new QueueCommand<Packet>.stop());
            worker_thread.join();
        }
    
        public override void advertise(InstanceReference instance_reference) throws IOError, Error {
            var advertisement = new Advertisement(instance_reference, new NetSimPeerInfo(identifier));
            conduit.advertise(identifier, advertisement);
        }
    
        public override void send(uint8[] bytes, PeerInfo peer_info) throws IOError, Error {
            NetSimPeerInfo info = (NetSimPeerInfo)peer_info;
            conduit.send_packet(this.identifier, new Bytes(info.identifier), new Bytes(bytes));
        }

        internal void receive_data(Bytes origin, Bytes data) {
            // Create the peer info
            var peer_info = new NetSimPeerInfo(origin);

            // Create the packet
            var packet = new Packet(peer_info, data);

            // Add packet to queue
            packet_queue.push(new QueueCommand<Packet>.with_payload(packet));
        }

        internal void receive_advertisment(Advertisement advertisement) {
            incoming_advertisment(advertisement);
        }
    
    }
}
