using LibPeer.Networks.Simulation;
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Aip;
using LibPeer.Networks;

using Gee;

namespace Discoverer {

    class DiscoverWorker : Object {

        private Muxer muxer = new Muxer();
        private Network network;
        private ApplicationInformationProtocol aip;
        private ApplicationInformation app_info;
        private Instance app_instance;
        private int id;

        public DiscoverWorker(int id, Network net) throws Error, IOError {
            this.id = id;
            network = net;
            network.bring_up();
            print("Instansiate\n");
            aip = new ApplicationInformationProtocol(muxer);
            print("Add network\n");
            aip.add_network(network);

            app_instance = new Instance("discovery_toy");
            app_info = new ApplicationInformation.from_instance(app_instance);
            app_info.new_group_peer.connect(group_peers_found);
            print("Add application\n");
            aip.add_application (app_info);
        }

        private void group_peers_found() {
            print("[GOAL!] Find application instance\n");
            aip.find_application_instance(app_info).on_answer.connect(found_peer);
        }

        private void found_peer(InstanceInformation info) {
            print("[GOAL!] I found a peer!\n");
        }

    }
}