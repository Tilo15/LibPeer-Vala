using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Networks;

using Gee;

namespace ExponentialPinger {

    class Pinger : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private Instance instance;
        private HashSet<InstanceReference> peers = new HashSet<InstanceReference>((m) => m.hash(), (a, b) => a.compare(b) == 0);

        public Pinger(Conduit conduit) throws Error, IOError {
            network = conduit.get_interface();
            network.bring_up();
            muxer.register_network(network);
            instance = muxer.create_instance("ExpontntialPinger");
            
            instance.incoming_greeting.connect((origin) => rx_greeting(origin));
            instance.incoming_payload.connect((packet) => rx_data(packet));
            network.incoming_advertisment.connect((adv) => rx_advertisement(adv));

            network.advertise(instance.reference);
            print("A pinger has been spawned\n");
        }

        private void rx_advertisement(Advertisement adv) throws Error, IOError {
            lock (peers) {
                if(!peers.contains(adv.instance_reference)) {
                    var peer_info = new GLib.List<PeerInfo>();
                    peer_info.append(adv.peer_info);
                    muxer.inquire(instance, adv.instance_reference, peer_info);
                }
            }
        }

        private void rx_greeting(InstanceReference origin) throws Error, IOError {
            lock (peers) {
                peers.add(origin);
            }
            muxer.send(instance, origin, "Hello World!".data);
        }

        private void rx_data(Packet packet) throws Error, IOError {
            lock (peers) {
                peers.add(packet.origin);
                network.advertise(instance.reference);
                print(@"RX DATA, I have $(peers.size) peers\n");
            }

            uint8[] data = new uint8[13];
            packet.stream.read(data);
            foreach (InstanceReference peer in peers) {
                muxer.send(instance, peer, data);
            }
        }

    }

}