using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Util;
using LibPeer.Networks;
using Gee;

namespace LibPeer.Protocols.Aip {

    public class ApplicationInformationProtocol : Object{

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
        protected Gee.List<ApplicationInformation> application_information = new Gee.LinkedList<ApplicationInformation>();

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

        private Gee.List<Query> pending_queries = new Gee.LinkedList<Query>();

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

        public void add_application(ApplicationInformation info) {
            // Save reference to application
            application_information.add(info);

            // Join group for this application
            join_query_group(info.namespace_bytes);

            // Hook up signals
            new_group_peer.connect((instance_ref, id) => {
                //print("New group peer?\n");
                if(id.compare(info.namespace_bytes) == 0) {
                    //print("New group peer\n");
                    info.new_group_peer();
                }
            });
        }

        public Query find_application_instance(ApplicationInformation app) {
            // We must be in a query group for this application
            assert(query_groups.has_key(app.namespace_bytes));

            // Create the query
            var query = new Query(new ByteComposer().add_byte(QUERY_APPLICATION).add_bytes(app.namespace_bytes).to_bytes());

            // Send the query
            initiate_query(query, query_groups.get(app.namespace_bytes));

            // Return the query
            return query;
        }

        public Query find_application_resource(ApplicationInformation app, Bytes resource_identifier) {
            // We must be in a query group for this application
            assert(query_groups.has_key(app.namespace_bytes));

            // Resource identifiers must be 32 bytes long
            assert(resource_identifier.length == 32);

            // Create the query
            var query = new Query(new ByteComposer().add_byte(QUERY_APPLICATION_RESOURCE).add_bytes(resource_identifier).add_bytes(app.namespace_bytes).to_bytes());

            // Send the query
            initiate_query(query, query_groups.get(app.namespace_bytes));

            // Return the query
            return query;
        }

        protected void rx_advertisement(Advertisement advertisement) {
            // Send an inquiry
            muxer.inquire(instance, advertisement.instance_reference, new PeerInfo[] { advertisement.peer_info });
        }

        protected void rx_greeting(InstanceReference greeting) {
            print("rx greeting\n");
            // Add to known peers
            discovered_peers.add(greeting);

            // Request capabilities from the instance
            request_capabilities(greeting).response.connect_after((m) => {
                rx_capabilities(greeting, m);
            });
        }

        protected void rx_capabilities(InstanceReference target, AipCapabilities capabilities) {
            print("rx capabilities\n");
            // Save the capabilities
            instance_capabilities.set(target, capabilities);

            // Can we ask the peer for our address?
            if(capabilities.address_info) {
                // Yes, do it
                request_address(target).response.connect(rx_address);
            }
            // Can we ask the peer for other peers?
            if(capabilities.find_peers) {
                // Yes, do it
                request_peers(target).response.connect(rx_peers);
            }
            // Can we send queries and answers to this peer?
            if(capabilities.query_answer) {
                //print("This peer is queryable\n");
                // Yes, add to default group
                default_group.add_peer(target);

                // Peer is now reachable for queries
                reachable_peers.add(target);

                // We now have a queryable peer
                if(!is_ready) {
                    //print("Ready B)\n");
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
            print("rx address\n");
            // We received peer info, add to our set
            peer_info.add(info);
            
            // Do we have any pending queries?
            if(pending_queries.size > 0) {
                print("Sending pending queries");
                // Clear the list
                var queries = pending_queries;
                pending_queries = new Gee.LinkedList<Query>();

                // Send pending queries
                foreach (var query in queries) {
                    send_query_answer(query);
                }
            }
        }

        protected void rx_peers(Gee.List<InstanceInformation> peers) {
            print("rx peers\n");
            // We received a list of peers running AIP, do we want more peers?
            if(!default_group.actively_connect) {
                // Don't worry about it
                //print("rx peers: ignored\n");
                return;
            }

            // Send out inquries to the peers
            foreach (var peer in peers) {
                //print("rx peers: Inquire\n");
                muxer.inquire(instance, peer.instance_reference, peer.connection_methods);
            }
        }

        protected Request<PeerInfo> request_address(InstanceReference target) {
            //print("request address\n");
            // Make the request
            var request = new ByteComposer().add_byte(REQUEST_ADDRESS).to_bytes();
            var peer_info_request = new Request<PeerInfo>();
            send_request(request, target).response.connect(s => {
                print("Address response\n");
                // Read the address (peer info)
                var address = PeerInfo.deserialise(s);
                // Callback
                print("Address response signal called\n");
                peer_info_request.response(address);
            });
            return peer_info_request;
        }

        protected Request<AipCapabilities> request_capabilities(InstanceReference target) {
            // Make the request
            //print("Request capabilities\n");
            var request_data = new ByteComposer().add_byte(REQUEST_CAPABILITIES).to_bytes();
            var request = new Request<AipCapabilities>();
            send_request(request_data, target).response.connect((s) => {
                // Read capabilities
                var target_capabilities = new AipCapabilities.from_stream(s);
                // Callback
                request.response(target_capabilities);
            });
            return request;
        }

        protected Request<Gee.List<InstanceInformation>> request_peers(InstanceReference target) {
            //print("request peers\n");
            // Make the request
            var request_data = new ByteComposer().add_byte(REQUEST_PEERS).to_bytes();
            var request = new Request<Gee.List<InstanceInformation>>();
            send_request(request_data, target).response.connect(s => {
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
                request.response(peers);
            });
            return request;
        }

        protected Request<InputStream> send_request(Bytes request, InstanceReference target) {
            var request_obj = new Request<InputStream>();
            // Open a stream with the peer
            transport.initialise_stream(target).established.connect((s) => {
                // Connect reply signal
                s.reply.connect(m => request_obj.response(m));

                // Send the request
                s.write(new ByteComposer().add_byte(DATA_FOLLOWING_REQUEST).add_bytes(request).to_byte_array());
                s.close();
            });
            return request_obj;
        }    
        
        protected void rx_stream(StpInputStream stream) {
            // Figure out what data follows
            uint8[] _following = new uint8[1];
            stream.read(_following);
            var following = _following[0];

            if(following == DATA_FOLLOWING_ANSWER && capabilities.query_answer) {
                print("RX Stream: Answer\n");
                handle_answer(stream);
            }
            else if(following == DATA_FOLLOWING_QUERY && capabilities.query_answer) {
                print("RX Stream: Query\n");
                handle_query(stream);
            }
            else if(following == DATA_FOLLOWING_REQUEST) {
                print("RX Stream: Request\n");
                handle_request(stream);
            }
            else {
                print("RX Stream: Invalid (stream closed)\n");
                stream.close();
            }

        }

        protected void handle_answer(InputStream stream) {
            print("Handle query answer\n");
            // Deserialise the answer
            var answer = new Answer.from_stream(stream);

            // Is this an answer to one of our queries?
            if(queries.has_key(answer.in_reply_to)) {
                // Yes, get the query
                var query = queries.get(answer.in_reply_to);

                // Get instance information from the answer
                var answer_stream = new MemoryInputStream.from_bytes(answer.data);
                var info = new InstanceInformation.from_stream(answer_stream);

                // Notify the query's subject listeners
                query.on_answer(info);
            }

            // Does this have somewhere to forward to?
            if(answer.path.length > 0) {
                // Put it back on its path
                send_answer(answer);
            }

            print("Answer handled!\n");
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
                        //print("I got a capabilities request\n");
                        capabilities.serialise(os);
                        break;
                    case REQUEST_ADDRESS:
                        //print("I got an address request\n");
                        muxer.get_peer_info_for_instance(os.target).serialise(os);
                        break;
                    case REQUEST_PEERS:
                        //print("I got a peers request\n");
                        // TODO: implement
                        os.write(new uint8[] {0});
                        break;
                }
                //print("Replied\n");
                os.close();
                //print("Reply stream closed\n");
            });

            // Have we encountered this peer before?
            if(!discovered_peers.contains(stream.origin)) {
                // No, add it
                discovered_peers.add(stream.origin);

                // Ask for capabilities
                request_capabilities(stream.origin).response.connect(c => rx_capabilities(stream.origin, c));
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

            // Get query data
            var query_data = query.data.get_data();

            // Find the query type
            var query_type = query_data[0];

            if(query_type == QUERY_GROUP) {
                print("Handle query: Group\n");
                // Get the group identifier
                var group_id = new Bytes(query_data[1:query_data.length]);

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
                print("Handle query: Application\n");
                // Get the application namespace
                var app_namespace = new Bytes(query_data[1:query_data.length]);

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
                print("Handle query: Application resource\n");
                // Read the label
                var label = new Bytes(query_data[1:33]);

                // Read the application namespace
                var app_namespace = new Bytes(query_data[33:query_data.length]);

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

        protected void queue_query_answer(Query query) {
            print("Queue query answer\n");
            // Do we have peer info to send yet?
            if(peer_info.size > 0) {
                print("Query sent immediately\n");
                // Yes, do it
                send_query_answer(query);
            }
            else {
                // No, wait for peer info
                pending_queries.add(query);
            }
        }

        protected void send_query_answer(Query query) {
            // Create some instance information
            var instance_info = new InstanceInformation(instance.reference, peer_info.to_array());

            // Serialise the info
            MemoryOutputStream stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            print("Serialising instance info\n");
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

        protected void join_query_group(Bytes group) {
            //print("Join query group\n");
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

        protected void send_group_query(Bytes group) {
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

        protected void initiate_query(Query query, QueryGroup group) {
            // Save a reference to the query
            queries.set(query.identifier, query);
            handled_query_ids.add(query.identifier);

            // Send the query
            send_query(query, group);
        }

        protected void send_query(Query query, QueryGroup group) {
            //print("Send query\n");
            // Does the query have any hops left?
            if(query.hops > MAX_QUERY_HOPS) {
                return;
            }

            // Loop over each instance in the query group
            foreach (var instance_ref in group) {
                //print("Contacting peer for query\n");
                transport.initialise_stream(instance_ref).established.connect(stream => {
                    // Tell the instance that the data that follows is a query
                    print("Query stream established\n");
                    stream.write(new uint8[] { DATA_FOLLOWING_QUERY });

                    print("Sending query body\n");
                    
                    // Write the query
                    query.serialise(stream);
                    
                    // Close the stream
                    print("Closing query stream\n");
                    stream.close();
                    print("Query sent to peer\n");
                });
            }
        }

        protected void send_answer(Answer answer) {
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
                print("Writing answer to stream\n");
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