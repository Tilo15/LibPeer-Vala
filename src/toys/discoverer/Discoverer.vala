using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Aip;
using LibPeer.Protocols.Stp;
using LibPeer.Networks;

using Gee;

namespace Discoverer {

    class DiscoverWorker : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private ApplicationInformationProtocol aip;
        private ApplicationInformation app_info;
        private StreamTransmissionProtocol stp;
        private Instance app_instance;
        private int id;

        public DiscoverWorker(int id, Network net) throws Error, IOError {
            this.id = id;
            network = net;
            network.bring_up();
            print("Instansiate AIP\n");
            aip = new ApplicationInformationProtocol(muxer);
            print("Add network\n");
            aip.add_network(network);
            
            print("Setup application instance\n");
            app_instance = muxer.create_instance("discovery_toy");
            app_info = new ApplicationInformation.from_instance(app_instance);
            app_info.resource_set.add(new Bytes(new uint8[32]));
            app_info.new_group_peer.connect(group_peers_found);
            app_instance.incoming_greeting.connect(greeted_by_peer);

            print("Instansiate STP\n");
            stp = new StreamTransmissionProtocol(muxer, app_instance);
            stp.incoming_stream.connect(ingress_stream_established);
            print("Add application\n");
            aip.add_application (app_info);
        }

        private void group_peers_found() {
            print("[GOAL!] Find application instance\n");
            aip.find_application_instance(app_info).on_answer.connect(found_peer);
        }

        private void found_peer(InstanceInformation info) {
            print("[GOAL!] I found a peer!\n");
            aip.find_application_resource(app_info, new Bytes(new uint8[32])).on_answer.connect(found_resource);
        }

        private void found_resource(InstanceInformation info) {
            print("[GOAL!] I found a resource!\n");
            var inquire_info = "Inquiring with:\n";
            foreach (var item in info.connection_methods) {
                inquire_info += @"\t$(item.to_string())\n";
            }
            print(inquire_info);
            muxer.inquire(app_instance, info.instance_reference, info.connection_methods);
        }

        private void greeted_by_peer(InstanceReference origin) {
            print("[GOAL!] I received a greeting!\n");
            stp.initialise_stream(origin).established.connect(egress_stream_established);
        }

        private void egress_stream_established(OutputStream stream) {
            print("[GOAL!] I established an egress stream to a peer!\n");
            stream.write(new uint8[] { 13, 'H', 'e', 'l', 'l', 'o', ',', ' ', 'w', 'o', 'r', 'l', 'd', '!'});
            stream.close();
        }

        private void ingress_stream_established(InputStream stream) {
            print("[GOAL!] An ingress stream has been established!\n");
            var message_size = new uint8[1];
            stream.read(message_size);

            var message = new uint8[message_size[0]];
            stream.read(message);

            stream.close();

            var message_str = new LibPeer.Util.ByteComposer().add_byte_array(message).to_string();
            print(@"[GOAL!] I received a message from a peer: '$(message_str)'\n");
        }

    }
}