
using LibPeer.Protocols;
using LibPeer.Networks;

namespace LibPeer.Routing {

    public class Router {

        protected Mx2.RoutingMuxer muxer;
        protected RouterDiscovery discovery;
        protected Network[] networks;
        protected GdpInstanceResolver resolver;

        public Router(Network[] net) {
            networks = net;
        }

        public void start() throws Error {
            resolver = new GdpInstanceResolver();
            muxer = new Mx2.RoutingMuxer(resolver);
            discovery = new RouterDiscovery(muxer);
            foreach(var network in networks) {
                network.bring_up();
                discovery.add_network(network);
            }
        }

    }


}