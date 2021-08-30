using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Networks;

using Gee;

namespace ExponentialPinger {

    class Pinger : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private Instance instance;
        private ConcurrentSet<InstanceReference> peers = new ConcurrentSet<InstanceReference>((a, b) => a.compare(b));
        private int id;

        public Pinger(int id, Conduit conduit) throws Error, IOError {
            this.id = id;
            network = conduit.get_interface();
            network.bring_up();
            muxer.register_network(network);
            instance = muxer.create_instance("ExpontntialPinger");
            
            instance.incoming_greeting.connect((origin) => rx_greeting(origin));
            instance.incoming_payload.connect((packet) => rx_data(packet));
            network.incoming_advertisment.connect((adv) => rx_advertisement(adv));

            network.advertise(instance.reference);
            print(@"[$id] A pinger has been spawned\n");
        }

        private void rx_advertisement(Advertisement adv) throws Error, IOError {
            if(!peers.contains(adv.instance_reference)) {
                muxer.inquire(instance, adv.instance_reference, new PeerInfo[] {adv.peer_info});
            }
        }

        private void rx_greeting(InstanceReference origin) throws Error, IOError {
            peers.add(origin);
            muxer.send(instance, origin, "Hello World!".data);
        }

        private void rx_data(Packet packet) throws Error, IOError {
            peers.add(packet.origin);
            network.advertise(instance.reference);
            print(@"[$id] RX DATA, I have $(peers.size) peers\n");

            uint8[] data = new uint8[13];
            packet.stream.read(data);
            foreach (InstanceReference peer in peers) {
                muxer.send(instance, peer, data);
            }
        }

    }

}