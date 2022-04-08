using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Gdp;
using LibPeer.Protocols.Stp;
using LibPeer.Networks;

using Gee;

namespace Discoverer {

    class DiscoverWorker : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private GeneralDiscoveryProtocol discovery;
        private GdpApplication discovery_app;
        private StreamTransmissionProtocol stp;
        private Instance app_instance;
        private int id;

        public DiscoverWorker(int id, Network net) throws Error, IOError {
            this.id = id;
            network = net;
            network.bring_up();
            print("Instansiate GDP\n");
            discovery = new GeneralDiscoveryProtocol(muxer);
            print("Add network\n");
            discovery.add_network(network);
            
            print("Setup application instance\n");
            app_instance = muxer.create_instance("discovery_toy");
            app_instance.incoming_greeting.connect(greeted_by_peer);
            discovery_app = discovery.add_application (app_instance);
            discovery_app.query_answered.connect(query_answered);

            var ch = discovery_app.create_app_challenge();
            var ch2 = new Challenge.from_values(ch.public_key, ch.challenge_blob);
            print(@"Solved own challenge: $(discovery_app.solve_app_challenge(ch2))\n");

            print("Instansiate STP\n");
            stp = new StreamTransmissionProtocol(muxer, app_instance);
            stp.incoming_stream.connect(ingress_stream_established);
            
            print("Querying\n");
            discovery.query_general(discovery_app);
        }

        private void query_answered(Answer answer) {
            print("[GOAL!] I received a query answer!\n");
            if(answer.query_summary.is_null_resource()) {
                if(!answer.query_summary.is_routed()) {
                    print("        Doing simple inquire\n");
                    muxer.inquire(app_instance, answer.instance_reference, answer.connection_methods);
                    return;
                }
    
                var path = answer.query_summary.get_path_info();
                var router = answer.query_summary.first_router;
                print("        Doing routed inquire\n");
                muxer.inquire(app_instance, answer.instance_reference, router.connection_methods, path);
            }
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