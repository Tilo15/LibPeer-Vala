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

        protected signal void new_group_peer(InstanceReference info, Bytes id);
        protected bool is_ready;
        protected TimeoutMap<InstanceReference, Bytes> pending_group_peers = new TimeoutMap<InstanceReference, Bytes>(120, (a) => a.hash(), (a, b) => a.compare(b) == 0);
        public signal void ready();

        private GLib.List<Query> pending_queries = new GLib.List<Query>();

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
            transport.incoming_stream.connect(rx_stream);
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
                if(pending_group_peers.has_key(target)) {
                    Bytes group;
                    pending_group_peers.unset(target, out group);
                    new_group_peer(target, group);
                }
            }
        }

        protected void rx_address(PeerInfo info) {
            // We received peer info, add to our set
            peer_info.add(info);
            
            // Do we have any pending queries?
            if(pending_queries.length() > 0) {
                // Clear the list
                var queries = pending_queries;
                pending_queries = null;

                // Send pending queries
                foreach (var query in queries) {
                    send_query_answer(query);
                }
            }
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
        
        protected void rx_stream(StpInputStream stream) {
            // Figure out what data follows
            uint8[] _following = new uint8[1];
            stream.read(_following);
            var following = _following[0];

            if(following == DATA_FOLLOWING_ANSWER && capabilities.query_answer) {
                handle_answer(stream);
            }
            else if(following == DATA_FOLLOWING_QUERY && capabilities.query_answer) {
                handle_query(stream);
            }
            else if(following == DATA_FOLLOWING_REQUEST) {
                handle_request(stream);
            }
            else {
                stream.close();
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

            // Does this have somewhere to forward to?
            if(answer.path.length > 0) {
                // Put it back on its path
                send_answer(answer);
            }
        }

        protected void handle_request(StpInputStream stream) throws IOError, Error {
            // Get the request type
            var _request_type = new uint8[1];
            stream.read(_request_type);
            var request_type = _request_type[0];

            // Is the request one of our capabilities?
            if(!capabilities.has_capability_for_request_code(request_type)) {
                // Ignore
                return;
            }

            // Reply to the sender
            transport.initialise_stream(stream.origin, stream.session_id).established.connect(os => {
                switch (request_type) {
                    case REQUEST_CAPABILITIES:
                        capabilities.serialise(os);
                        break;
                    case REQUEST_ADDRESS:
                        muxer.get_peer_info_for_instance(os.target).serialise(os);
                        break;
                    case REQUEST_PEERS:
                        // TODO: implement
                        os.write(new uint8[] {0});
                        break;
                }
                os.close();
            });

            // Have we encountered this peer before?
            if(!discovered_peers.contains(stream.origin)) {
                // No, add it
                discovered_peers.add(stream.origin);

                // Ask for capabilities
                request_capabilities(stream.origin, c => rx_capabilities(stream.origin, c));
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

            // Find the query type
            var query_type = query.data[0];

            if(query_type == QUERY_GROUP) {
                // Get the group identifier
                var group_id = query.data[1:-1];

                // Are we not in this group, but joining all?
                if(join_all_groups && !query_groups.has_key(group_id)) {
                    // Join the group
                    join_query_group(group_id);
                }

                // Are we in this group?
                if(query_groups.has_key(group_id)) {
                    // Yes, send a reply
                    queue_query_answer(query);
                }

                // This is a query for a group, forward on to the default group
                send_query(query, default_group);
            }
            else if(query_type == QUERY_APPLICATION) {
                // Get the application namespace
                var app_namespace = new Bytes(query.data[1:-1]);

                // Are we in a group for this namespace?
                if(query_groups.has_key(app_namespace)) {
                    // Yes, find relevent ApplicationInformation
                    foreach (var app in application_information) {
                        // Is this app relevent? TODO: Use a hashmap
                        if(app.namespace_bytes.compare(app_namespace) == 0) {
                            // Yes, answer the query
                            queue_query_answer(query);
                        }
                    }

                    // Forward onto the application group
                    send_query(query, query_groups.get(app_namespace));
                }
            }
            else if(query_type == QUERY_APPLICATION_RESOURCE) {
                // Read the label
                var label = new Bytes(query.data[1:33]);

                // Read the application namespace
                var app_namespace = new Bytes(query.data[33:-1]);

                // Are we in a group for this namespace?
                if(query_groups.has_key(app_namespace)) {
                    // Yes, find relevent ApplicationInformation
                    foreach (var app in application_information) {
                        // Is this app relevent and does it have this resource?
                        if(app.namespace_bytes.compare(app_namespace) == 0 && app.resource_set.contains(label)) {
                            // Yes, answer the query
                            queue_query_answer(query);
                        }
                    }

                    // Forward onto the application group
                    send_query(query, query_groups.get(app_namespace));
                }
            }

            
        }

        public void queue_query_answer(Query query) {
            // Do we have peer info to send yet?
            if(peer_info.size > 0) {
                // Yes, do it
                send_query_answer(query);
            }
            else {
                // No, wait for peer info
                pending_queries.append(query);
            }
        }

        public void send_query_answer(Query query) {
            // Create some instance information
            var instance_info = new InstanceInformation(instance.reference, peer_info.to_array());

            // Serialise the info
            MemoryOutputStream stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            instance_info.serialise(stream);
            stream.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();

            // Send the instance information in the answer
            var answer = new Answer() {
                data = new Bytes(buffer),
                in_reply_to = query.identifier,
                path = query.return_path
            };

            // Send the answer
            send_answer(answer);
        }

        public void join_query_group(Bytes group) {
            // Create the query group
            query_groups.set(group, new QueryGroup());

            // Are we ready?
            if(is_ready) {
                // Yes, send the query
                send_group_query(group);
            }
            else {
                // No, do it when we are ready
                ready.connect(() => send_group_query(group));
            }
        }

        public void send_group_query(Bytes group) {
            // Construct a query asking for peers in the group
            var query = new Query(new ByteComposer().add_byte(QUERY_GROUP).add_bytes(group).to_bytes());

            // Handler for query answer
            query.on_answer.connect(answer => {
                // Add to group
                query_groups.get(group).add_peer(answer.instance_reference);

                // Are we already connected to this peer?
                if(reachable_peers.contains(answer.instance_reference)) {
                    // No need to greet, already connected
                    new_group_peer(answer.instance_reference, group);
                    return;
                }

                // When this peer has greeted us, notify the group
                pending_group_peers.set(answer.instance_reference, group);

                // Inquire
                muxer.inquire(instance, answer.instance_reference, answer.connection_methods);
            });

            // Send the query
            initiate_query(query, default_group);
        }

        public void initiate_query(Query query, QueryGroup group) {
            // Save a reference to the query
            queries.set(query.identifier, query);
            handled_query_ids.add(query.identifier);

            // Send the query
            send_query(query, group);
        }

        public void send_query(Query query, QueryGroup group) {
            // Does the query have any hops left?
            if(query.hops > MAX_QUERY_HOPS) {
                return;
            }

            // Loop over each instance in the query group
            foreach (var instance_ref in group) {
                transport.initialise_stream(instance_ref).established.connect(stream => {
                    // Tell the instance that the data that follows is a query
                    stream.write(new uint8[] { DATA_FOLLOWING_QUERY });

                    // Write the query
                    query.serialise(stream);

                    // Close the stream
                    stream.close();
                });
            }
        }

        public void send_answer(Answer answer) {
            // Get (and remove) the last item from the path list
            var send_to = answer.path[answer.path.length-1];
            answer.path.length --;

            // Don't send answers to queries we haven't received
            if(!query_response_count.has_key(answer.in_reply_to)) {
                return;
            }

            // Don't send answers to queries that have exceeded their maximum replies
            var response_count = query_response_count.get(answer.in_reply_to);
            if(response_count < 1) {
                return;
            }

            // Decrement response counter (stops at 0)
            query_response_count.set(answer.in_reply_to, response_count - 1);

            // Open a stream with the instance
            transport.initialise_stream(send_to).established.connect(stream => {
                // Tell the instance that the data that follows is an answer
                stream.write(new uint8[] { DATA_FOLLOWING_ANSWER });

                // Write the answer
                answer.serialise(stream);

                // Close the stream
                stream.close();
            });
        }
        

    }

}