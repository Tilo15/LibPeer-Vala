using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Util;
using LibPeer.Networks;
using Gee;

namespace LibPeer.Protocols.Aip {

    class ApplicationInformationProtocol {

        internal const uint8 DATA_FOLLOWING_REQUEST = 'R';
        internal const uint8 DATA_FOLLOWING_QUERY = 'Q';
        internal const uint8 DATA_FOLLOWING_ANSWER = 'A';

        internal const uint8 REQUEST_CAPABILITIES = 'C';
        internal const uint8 REQUEST_ADDRESS = 'A';
        internal const uint8 REQUEST_PEERS = 'P';

        internal const uint8 QUERY_GROUP = 'G';
        internal const uint8 QUERY_APPLICATION = 'A';
        internal const uint8 QUERY_APPLICATION_RESOURCE = 'R';

        internal const uint8 CAPABILITY_ADDRESS_INFO = 'A';
        internal const uint8 CAPABILITY_FIND_PEERS = 'P';
        internal const uint8 CAPABILITY_QUERY_ANSWER = 'Q';

        private const int MAX_QUERY_HOPS = 16;


        protected AipCapabilities capabilities;
        protected bool join_all_groups = false;
        protected Gee.List<ApplicationInformation> application_information;

        protected Muxer muxer;
        protected Instance instance;
        protected StreamTransmissionProtocol transport;

        protected HashSet<InstanceReference> discovered_peers = new HashSet<InstanceReference>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected ConcurrentHashMap<InstanceReference, PeerInfo> peer_connection_methods = new ConcurrentHashMap<InstanceReference, PeerInfo>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected ConcurrentHashMap<InstanceReference, AipCapabilities> instance_capabilities = new ConcurrentHashMap<InstanceReference, AipCapabilities>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected QueryGroup default_group = new QueryGroup (20);
        protected ConcurrentHashMap<Bytes, QueryGroup> query_groups = new ConcurrentHashMap<Bytes, QueryGroup>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected HashSet<InstanceReference> reachable_peers = new HashSet<InstanceReference>((a) => a.hash(), (a, b) => a.compare(b) == 0);

        protected TimeoutMap<Bytes, Query> queries = new TimeoutMap<Bytes, Query>(120, (a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected TimeoutMap<Bytes, int> query_response_count = new TimeoutMap<Bytes, int>(120, (a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected HashSet<Bytes> handled_query_ids = new HashSet<Bytes>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected HashSet<PeerInfo> peer_info = new HashSet<PeerInfo>((a) => a.hash(), (a, b) => a.equals(b));
        protected signal void new_peer_info(PeerInfo info);

        protected signal void new_group_peer(PeerInfo info, Bytes id);
        protected bool is_ready;
        protected signal void on_peer_greet(InstanceReference info);
        public signal void ready();

        public ApplicationInformationProtocol(Muxer muxer, AipCapabilities? capabilities = null, bool join_all = false) {
            if(capabilities == null) {
                this.capabilities = new AipCapabilities (){
                    address_info = true,
                    find_peers = true,
                    query_answer = true
                };
            }
            else {
                this.capabilities = capabilities;
            }

            this.join_all_groups = join_all;

            this.muxer = muxer;
            instance = muxer.create_instance ("AIP");
            transport = new StreamTransmissionProtocol(muxer, instance);

            // Attach signal handlers
            instance.incoming_greeting.connect(rx_greeting);
            //transport.incoming_stream()
        }

        public void add_network(Network network) {
            network.incoming_advertisment.connect(rx_advertisement);
            muxer.register_network(network);
            network.advertise(instance.reference);
        }

        protected void rx_advertisement(Advertisement advertisement) {
            // Send an inquiry
            muxer.inquire(instance, advertisement.instance_reference, new PeerInfo[] { advertisement.peer_info });
        }

        protected void rx_greeting(InstanceReference greeting) {
            // Add to known peers
            discovered_peers.add(greeting);

            // Request capabilities from the instance
            request_capabilities(greeting, m => rx_capabilities(greeting, m));
        }

        protected void rx_capabilities(InstanceReference target, AipCapabilities capabilities) {
            // Save the capabilities
            instance_capabilities.set(target, capabilities);

            // Can we ask the peer for our address?
            if(capabilities.address_info) {
                // Yes, do it
                request_address(target, rx_address);
            }
            // Can we ask the peer for other peers?
            if(capabilities.find_peers) {
                // Yes, do it
                request_peers(target, rx_peers);
            }
            // Can we send queries and answers to this peer?
            if(capabilities.query_answer) {
                // Yes, add to default group
                default_group.add_peer(target);

                // Peer is now reachable for queries
                reachable_peers.add(target);

                // We now have a queryable peer
                if(!is_ready) {
                    is_ready = true;
                    ready();
                }

                // There may may be code waiting for this moment
                on_peer_greet(target);
            }
        }

        protected void rx_address(PeerInfo info) {
            // We received peer info, add to our set
            peer_info.add(info);
            new_peer_info(info);
        }

        protected void rx_peers(Gee.List<InstanceInformation> peers) {
            // We received a list of peers running AIP, do we want more peers?
            if(!default_group.actively_connect) {
                // Don't worry about it
                return;
            }

            // Send out inquries to the peers
            foreach (var peer in peers) {
                muxer.inquire(instance, peer.instance_reference, peer.connection_methods);
            }
        }

        protected void request_address(InstanceReference target, Func<PeerInfo> callback) {
            // Make the request
            var request = new ByteComposer().add_byte(REQUEST_ADDRESS).to_bytes();
            send_request(request, target, s => {
                // Read the address (peer info)
                var address = PeerInfo.deserialise(s);
                // Callback
                callback(address);
            });
        }

        protected void request_capabilities(InstanceReference target, Func<AipCapabilities> callback) {
            // Make the request
            var request = new ByteComposer().add_byte(REQUEST_CAPABILITIES).to_bytes();
            send_request(request, target, s => {
                // Read capabilities
                var target_capabilities = new AipCapabilities.from_stream(s);
                // Callback
                callback(target_capabilities);
            });
        }

        protected void request_peers(InstanceReference target, Func<Gee.List<InstanceInformation>> callback) {
            // Make the request
            var request = new ByteComposer().add_byte(REQUEST_PEERS).to_bytes();
            send_request(request, target, s => {
                var dis = new DataInputStream(s);
                dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;
                // Read number of peers
                var peer_count = dis.read_byte();

                // Create the list
                var peers = new ArrayList<InstanceInformation>();

                // Read the peers (instance info)
                for (int i = 0; i < peer_count; i++) {
                    peers.add(new InstanceInformation.from_stream(dis));
                }

                // Callback
                callback(peers);
            });
        }

        protected void send_request(Bytes request, InstanceReference target, Func<InputStream> callback) {
            // Open a stream with the peer
            transport.initialise_stream(target).established.connect((s) => {
                // Connect reply signal
                s.reply.connect(m => callback(m));

                // Send the request
                s.write(new ByteComposer().add_byte(DATA_FOLLOWING_REQUEST).add_bytes(request).to_byte_array());
                s.close();
            });
        }    
        
        protected void rx_stream(InputStream stream) {
            // Figure out what data follows
            uint8[] _following = new uint8[1];
            stream.read(_following);
            var following = _following[0];

            if(following == DATA_FOLLOWING_ANSWER && capabilities.query_answer) {
                
            }

        }

        protected void handle_answer(InputStream stream) {
            // Deserialise the answer
            var answer = new Answer.from_stream(stream);

            // Is this an answer to one of our queries?
            if(queries.has_key(answer.in_reply_to)) {
                // Yes, get the query
                var query = queries.get(answer.in_reply_to);

                // Get instance information from the answer
                var info = new InstanceInformation.from_stream(new MemoryInputStream.from_bytes(answer.data));

                // Notify the query's subject listeners
                query.on_answer(info);
            }
        }

        protected void handle_query(StpInputStream stream) throws IOError, Error {
            // Deserialise the query
            var query = new Query.from_stream(stream);

            // Have we come across this query before?
            if(handled_query_ids.contains(query.identifier)) {
                // Don't forward
                return;
            }

            // Mark as handled
            handled_query_ids.add(query.identifier);

            // Create a replies counter
            query_response_count.set(query.identifier, query.max_replies);

            // Append the originator of the stream to the query reply path
            query.append_return_hop(stream.origin);

            // Increment the query hops
            query.hops ++;

            // Read through the query data
            var dis = new DataInputStream(new MemoryInputStream.from_bytes(query.data));
            dis.byte_order = DataStreamByteOrder.BIG_ENDIAN;

            // Find the query type
            var query_type = dis.read_byte();

            if(query_type == QUERY_GROUP) {
                // Get the group identifier
                var group_id = dis.read_bytes(query.data.length - 1);

                // Are we not in this group, but joining all?
                if(join_all_groups && !query_groups.has_key(group_id)) {
                    // Join the group
                    
                }
            }
        }

        public void join_query_group(Bytes group) {
            // Create the query group
            query_groups.set(group, new QueryGroup());

            // TODO continue
        }

        public void send_group_query(Bytes group) {
            // Construct a query asking for peers in the group
            var query = new Query(new ByteComposer().add_byte(QUERY_GROUP).add_bytes(group).to_bytes());

            // 
        }
        

    }

}