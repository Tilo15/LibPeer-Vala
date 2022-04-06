using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Networks;
using LibPeer.Util;
using Sodium.Asymmetric;
using Gee;


namespace LibPeer.Protocols.Gdp {

    private enum Command {
        ASSOCIATE = 0,
        PEERS = 1,
        QUERY = 2,
        ANSWER = 3,
        DISASSOCIATE = 255
    }

    public class GeneralDiscoveryProtocol {

        private const int QUERY_MAX_HOPS = 10;
        public const uint8[] EMPTY_RESOURCE = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

        protected uint8[] public_key;
        protected uint8[] private_key;
        protected uint8[] encryption_key;
        protected ConcurrentHashMap<Bytes, InstanceReference> peers = new ConcurrentHashMap<Bytes, InstanceReference>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected ConcurrentHashMap<Bytes, GdpApplication> applications = new ConcurrentHashMap<Bytes, GdpApplication>((a) => a.hash(), (a, b) => a.compare(b) == 0);
        protected HashSet<PeerInfo> peer_info = new HashSet<PeerInfo>((a) => a.hash(), (a, b) => a.equals(b));
        protected AsyncQueue<QueryBase> query_queue = new AsyncQueue<QueryBase>();
        protected Muxer muxer;
        protected Instance instance;
        protected StreamTransmissionProtocol transport;

        public bool is_ready {
            get {
                return peers.size > 0 && peer_info.size > 0;
            }    
        }

        public GdpApplication add_application(Instance instance) {
            var app = new GdpApplication(instance.application_namespace, instance.reference);
            applications.set(new Bytes(app.namespace_hash), app);
            return app;
        }

        public void add_network(Network network) {
            network.incoming_advertisment.connect(handle_advertisement);
            muxer.register_network(network);
            network.advertise(instance.reference);
        }

        public void query_general(GdpApplication app, uint8[]? private_data = null, bool allow_routing = true) throws Error {
            var query = new Query() {
                sender_id = public_key,
                max_hops = QUERY_MAX_HOPS,
                allow_routing = allow_routing,
                namespace_hash = app.namespace_hash,
                resource_hash = EMPTY_RESOURCE,
                challenge = app.create_app_challenge()
            };
            if(private_data != null) {
                var nonce = new uint8[Sodium.Symmetric.NONCE_BYTES];
                Sodium.Random.random_bytes(nonce);
                query.add_private_blob(private_data, encryption_key, nonce);
            }
            query.sign(private_key);
            send_query(query);
        }

        public void query_resource(GdpApplication app, uint8[] resource_identifier, Challenge challenge, uint8[]? private_data = null, bool allow_routing = true) throws Error requires (resource_identifier.length == ChecksumType.SHA512.get_length()) {
            var query = new Query() {
                sender_id = public_key,
                max_hops = QUERY_MAX_HOPS,
                allow_routing = allow_routing,
                namespace_hash = app.namespace_hash,
                resource_hash = resource_identifier,
                challenge = challenge
            };
            if(private_data != null) {
                var nonce = new uint8[Sodium.Symmetric.NONCE_BYTES];
                Sodium.Random.random_bytes(nonce);
                query.add_private_blob(private_data, encryption_key, nonce);
            }
            query.sign(private_key);
            send_query(query);
        }

        public GeneralDiscoveryProtocol(Muxer muxer) {
            this.muxer = muxer;
            instance = muxer.create_instance ("GDP");
            transport = new StreamTransmissionProtocol(muxer, instance);

            // Generate identity
            public_key = new uint8[Signing.PUBLIC_KEY_BYTES];
            private_key = new uint8[Signing.SECRET_KEY_BYTES];
            Signing.generate_keypair(public_key, private_key);
            encryption_key = Sodium.Symmetric.generate_key();

            // Attach signal handlers
            instance.incoming_greeting.connect(handle_greeting);
            transport.incoming_stream.connect(handle_stream);
        }

        private void handle_stream(StreamTransmissionProtocol stp, StpInputStream stream) {
            var command = new uint8[1];
            stream.read(command);

            switch (command[0]) {
                case Command.ASSOCIATE:
                    handle_association(stream);
                    break;
                case Command.PEERS:
                    handle_peers(stream);
                    break;
                case Command.QUERY:
                    handle_query(stream);
                    break;
                case Command.ANSWER:
                    handle_answer(stream);
                    break;
                case Command.DISASSOCIATE:
                    handle_disassociation(stream);
                    break;
            }
            stream.close();
        }

        private void handle_greeting(InstanceReference origin) {
            send_command(origin, Command.ASSOCIATE, s => serialise_association_information(origin, s), handle_association_reply);
        }

        protected void handle_advertisement(Advertisement advertisement) {
            // Send an inquiry
            muxer.inquire(instance, advertisement.instance_reference, new PeerInfo[] { advertisement.peer_info });
        }

        private void handle_association_reply(StpInputStream stream) {
            handle_association(stream, true);
        }

        private void handle_association(StpInputStream stream, bool is_final = false) throws Error {
            var id = new ByteComposer().add_from_stream(stream, Signing.PUBLIC_KEY_BYTES).to_bytes();
            var peer_info = PeerInfo.deserialise(stream);
            if(is_final) {
                add_peer(id, stream.origin, peer_info);
            }
            if(!is_final) {
                var origin = stream.origin;
                transport.initialise_stream(origin, stream.session_id).established.connect(s => {
                    serialise_association_information(origin, s);
                    stream.close();
                    add_peer(id, stream.origin, peer_info);
                });
            }
        }

        private void serialise_association_information(InstanceReference origin, OutputStream stream) {
            var peer_info = muxer.get_peer_info_for_instance(origin);
            stream.write(public_key);
            peer_info.serialise(stream);
        }

        private void handle_peers(StpInputStream stream) throws Error {
            // todo
        }

        private void handle_query(StpInputStream stream) throws Error {
            var dis = new DataInputStream(stream);
            var query = QueryBase.new_from_stream(dis);
            var summary = new QuerySummary(query);
            
            if(!summary.validate()) {
                return;
            }

            // Do we have the specified app?
            if(applications.has_key(summary.namespace_hash)) {
                var app = applications.get(summary.namespace_hash);
                if(summary.is_null_resource()) {
                    if(app.solve_app_challenge(summary.challenge)) {
                        answer(stream, query, app);
                    }
                }
                else {
                    app.challenged(summary.resource_hash, summary.challenge);
                    if(summary.challenge.solved) {
                        answer(stream, query, app);
                    }
                }
            }

            // Should we forward this?
            if(summary.should_forward(new Bytes(public_key))) {
                forward_query(query);
            }
        }

        private void handle_answer(StpInputStream stream) {
            var dis = new DataInputStream(stream);
            var answer = new Answer.from_stream(dis);
            
            if(!answer.query_summary.has_visited(new Bytes(public_key))) {
                // Drop any answer that we had no part in forwarding the query for
                return;
            }

            if(!answer.query_summary.validate()) {
                // Drop any answer that is based on a query that is invalid
                return;
            }

            var query = answer.query;
            var forward = false;
            while(query is WrappedQuery) {
                var wrapped = (WrappedQuery)query;
                query = wrapped.query;
                if(query.compare_sender(public_key)) {
                    forward = true;
                    break;
                }
            }

            if(forward) {
                var sender_id = new Bytes(query.sender_id);
                if(peers.has_key(sender_id)) {
                    send_command(peers.get(sender_id), Command.ANSWER, answer.serialise);
                }
            }
            else if(query.compare_sender(public_key) && applications.has_key(answer.query_summary.namespace_hash)) {
                var app = applications.get(answer.query_summary.namespace_hash);
                answer.query_summary.read_private_blob(encryption_key);
                app.query_answered(answer);
            }
        }

        private void handle_disassociation(StpInputStream stream) throws Error {
            var id = new ByteComposer().add_from_stream(stream, Signing.PUBLIC_KEY_BYTES).to_bytes();
            if(peers.has_key(id)) {
                var peer = peers.get(id);
                if(peer.compare(stream.origin) == 0) {
                    peers.remove(id);
                }
            }
        }

        private void answer(StpInputStream stream, QueryBase query, GdpApplication app) throws Error {
            var answer_obj = new Answer(query, app.instance_reference, get_peer_info());
            send_command(stream.origin, Command.ANSWER, answer_obj.serialise);
        }

        private void forward_query(QueryBase query) throws Error {
            var wrapped = new WrappedQuery(public_key, query);
            wrapped.sign(private_key);
            send_query(query);
        }

        private void send_query(QueryBase query) throws Error {
            query_queue.push(query);
        }

        private bool queue_running = false;
        private void start_queue_worker() {
            queue_running = true;
            ThreadFunc<bool> queue_worker = () => {
                while (queue_running) {
                    var query = query_queue.pop();
                    var summary = new QuerySummary(query);
                    try {
                        foreach(var peer in peers) {
                            if(!summary.has_visited(peer.key)) {
                                send_command(peer.value, Command.QUERY, query.serialise);
                            }
                            Posix.sleep(Random.int_range(5, 30));
                        }
                    }
                    catch (Error e) {
                        printerr(@"Exception on query sender queue: $(e.message)\n");
                    }
                }
                return false;
            };

            new Thread<bool>(@"GDP-Query-Sender", queue_worker);
        }

        private PeerInfo[] get_peer_info() {
            lock(peer_info) {
                var output = new PeerInfo[peer_info.size];
                int i = 0;
                foreach(var info in peer_info) {
                    output[i] = info;
                    i++;
                }
                return output;
            }
        }

        private void add_peer(Bytes id, InstanceReference ir, PeerInfo info) {
            peer_info.add(info);
            peers.set(id, ir);
            if(!queue_running) {
                start_queue_worker();
            }
        }

        private delegate void ReplyHandler(StpInputStream stream);

        private void send_command(InstanceReference peer, Command command, ByteComposer.StreamComposer serialiser, ReplyHandler? handler = null) throws Error {
            var message = new ByteComposer().add_byte(command).add_with_stream(serialiser).to_byte_array();
            transport.initialise_stream(peer).established.connect(s => {
                if(handler != null) {
                    s.reply.connect(s => handler(s));
                }
                s.write(message);
                s.close();
            });
        }
    }
}