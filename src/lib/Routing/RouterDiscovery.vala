
using LibPeer.Protocols.Gdp;
using LibPeer.Protocols.Mx2;

namespace LibPeer.Routing {

    public class RouterDiscovery : GeneralDiscoveryProtocol {

        public InstanceReference router_instance { get; protected set; }

        protected GdpInstanceResolver instance_resolver;

        public RouterDiscovery(RoutingMuxer muxer) {
            base(muxer);
            router_instance = muxer.instance_reference;
            instance_resolver = (GdpInstanceResolver)muxer.resolver;
        }

        protected override void forward_query(QueryBase query, InstanceReference origin) throws Error {
            // Forward query normally for peers that won't require routing
            base.forward_query(query, origin);

            // Create routing information
            var router = new RouterInfo(router_instance, get_peer_info());

            // Create a wrapped query with routing information
            var wrapped = new WrappedQuery(public_key, query, router);
            wrapped.sign(private_key);

            // Send to all networks except the originating network
            var network = muxer.get_target_network_for_instance(origin);
            queue_query(wrapped, null, network);
        }

        protected override void process_answer(Answer answer) {
            var routers = answer.query_summary.get_routers();
            for(var i = 0; i < routers.length; i++) {
                if(routers[i].instance_reference.compare(router_instance) == 0) {
                    if(i == 0) {
                        instance_resolver.add_peer_info(answer.instance_reference, answer.connection_methods);
                        break;
                    }
                    instance_resolver.add_peer_info(routers[i-1].instance_reference, routers[i-1].connection_methods);
                    break;
                }
            }

            base.process_answer(answer);
        }

    }


}