
using LibPeer.Util;

namespace LibPeer.Protocols.Mx2 {

    public class RoutingMuxer : Muxer {

        public InstanceReference instance_reference {
            owned get {
                return router_instance.reference;
            }
        }

        protected Instance router_instance = new Instance("mx2-router");

        public InstanceResolver resolver { get; protected set; }

        public RoutingMuxer(InstanceResolver instance_resolver) {
            resolver = instance_resolver;
        }
        
        protected override void handle_receiption(Networks.Receiption receiption) {
            // Pass to the assembler
            var stream = assembler.handle_data(receiption.stream);

            // Did the assembler return a stream?
            if(stream == null) {
                // No, message is not fully assembled
                return;
            }

            // Read the incoming frame
            var frame = new RouterFrame.from_stream(stream);

            //  print(@"[RoutingMuxer] Got frame from $(frame.origin)\n");
            // Is the frame for an application on this machine?
            if(instances.has_key(frame.destination)) {
                // This frame is for us, don't route
                var full_frame = frame.to_full_frame(instances);
                if(full_frame.read_status == FrameReadStatus.OK) {
                    //  print(@"[RoutingMuxer] Handling frame normally $(frame.origin)\n");
                    handle_frame(full_frame, receiption);
                }
                return;
            }

            //  print("[RoutingMuxer] Frame not consumed by local host\n");

            // Save the connection details
            save_instance_mapping(frame, receiption);

            // Is the frame routed through us?
            if(get_instance_index(frame.via) != -1) {
                // Yes, help it along
                //  print("[RoutingMuxer] We are a router in this frame, find next hop\n");
                var next_hop = get_next_hop(frame);
                forward_frame(frame, next_hop);
                //  print("[RoutingMuxer] Frame forwarded to next hop\n");
                return;
            }

            //  print("[RoutingMuxer] Frame discarded\n");
            // This frame has nothing to do with us
            Frame dispel_frame = new Frame(frame.origin, frame.destination, frame.via.return_path, PayloadType.DISPEL, new uint8[0], FrameCrypto.NONE);
            fragmenter.send_frame(dispel_frame, null, receiption.network, receiption.peer_info);
        }

        protected void forward_frame(RouterFrame frame, InstanceReference next_hop) {
            if(remote_instance_mapping.has_key(next_hop)) {
                var instance_info = remote_instance_mapping.get(next_hop);
                fragmenter.send_buffer(frame.to_buffer(), instance_info.network, instance_info.peer_info);
                return;
            }
            
            var suggestions = resolver.suggest_peer_info(next_hop);
            foreach(var suggestion in suggestions) {
                var network_type = suggestion.get_network_identifier();
                var frame_buffer = frame.to_buffer();
                foreach(var network in networks.get(network_type)) {
                    fragmenter.send_buffer(frame_buffer, network, suggestion);
                }
            }
        }

        private int get_instance_index(PathInfo path) {
            var i = 0;
            foreach(var repeater in path.repeaters) {
                if(repeater.compare(router_instance.reference) == 0) {
                    return i;
                }
                i++;
            }
            return -1;
        }

        private InstanceReference get_next_hop(RouterFrame frame) {
            var index = get_instance_index(frame.via);
            if(frame.via.repeaters.size > index + 1) {
                return frame.via.repeaters.get(index+1);
            }
            return frame.destination;
        }

        private InstanceReference get_previous_hop(RouterFrame frame) {
            var index = get_instance_index(frame.via);
            if(index != 0) {
                return frame.via.repeaters.get(index-1);
            }
            return frame.origin;
        }

        private void save_instance_mapping(RouterFrame frame, Networks.Receiption receiption) {
            var instance_ref = get_previous_hop(frame);
            remote_instance_mapping.set(instance_ref, new InstanceAccessInfo() { 
                network = receiption.network,
                peer_info = receiption.peer_info,
                path_info = new PathInfo.empty()
            });

            //  print(@"Saved instance mapping with address $(receiption.peer_info.to_string()) due to routed frame\n");
        }

    }

}