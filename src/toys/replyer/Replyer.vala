using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Networks;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;

using Gee;

namespace NumericReplyer {

    class Replyer : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private Instance instance;
        private ConcurrentSet<InstanceReference> peers = new ConcurrentSet<InstanceReference>((a, b) => a.compare(b));
        private StreamTransmissionProtocol transport;
        private int id;

        public Replyer(int id, Conduit conduit) throws Error, IOError {
            this.id = id;
            network = conduit.get_interface (0, 0, 0.0f);
            network.bring_up ();
            muxer.register_network (network);
            instance = muxer.create_instance ("GiveFile");
            transport = new StreamTransmissionProtocol (muxer, instance);

            instance.incoming_greeting.connect((origin) => rx_greeting(origin));
            network.incoming_advertisment.connect(rx_advertisement);
            transport.incoming_stream.connect(incoming);
            
            network.advertise(instance.reference);
        }

        void rx_advertisement(Advertisement adv) {
            print("rx_advertisement\n");
            if(!peers.contains(adv.instance_reference)) {
                muxer.inquire(instance, adv.instance_reference, new PeerInfo[] {adv.peer_info});
            }
        }

        void rx_greeting(InstanceReference origin) {
            print("rx_greeting\n");
            peers.add(origin);
            transport.initialise_stream(origin).established.connect(s => {
                s.reply.connect(sr => {
                    var reply = new uint8[1];
                    sr.read(reply);
                    if(reply[0] == 2) {
                        print("RX2\n");
                        transport.initialise_stream(sr.origin, sr.session_id).established.connect(srr => {
                           srr.reply.connect(srrr => {
                               srrr.read(reply);
                               if(reply[0] == 4) {
                                   print("Yipee\n");
                               }
                               else {
                                    print("Got invalid reply! (Level 1)\n");
                               }
                            });
                            print("TX3\n");
                            srr.write(new uint8[] {3});
                        });
                    }
                    else {
                        print("Got invalid reply! (Level 1)\n");
                    }
                });
                print("TX1\n");
                s.write(new uint8[] {1});
            });
        }

        void incoming(StpInputStream stream) {
            print("I have a new stream\n");
            var data = new uint8[1];
            stream.read(data);

            if(data[0] == 1) {
                print("RX1\n");
                transport.initialise_stream(stream.origin, stream.session_id).established.connect(sr => {
                    sr.reply.connect(srr => {
                        srr.read(data);
                        if(data[0] == 3) {
                            print("RX3\n");
                            transport.initialise_stream(srr.origin, srr.session_id).established.connect(srr => {
                                print("TX4\n");
                                srr.write(new uint8[] {4});
                                print("My work is done\n");
                            });
                        }
                        else {
                            print("Got invalid reply\n");
                        }
                    });
                    print("TX2\n");
                    sr.write(new uint8[] {2});
                });
            }
            else {
                print("Got invalid initial data\n");
            }
        }

    }

}