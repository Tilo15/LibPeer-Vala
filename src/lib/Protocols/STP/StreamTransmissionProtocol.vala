using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Messages;
using LibPeer.Protocols.Stp.Sessions;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Util;
using Gee;

namespace LibPeer.Protocols.Stp {

    public class StreamTransmissionProtocol {

        public const uint8[] EMPTY_REPLY_TO = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

        private Muxer muxer { get; set; }

        private Instance instance { get; set; }

        public signal void incoming_stream(StpInputStream stream);

        private ConcurrentHashMap<Bytes, Negotiation> negotiations = new ConcurrentHashMap<Bytes, Negotiation>(k => k.hash(), (a, b) => a.compare(b) == 0);

        private ConcurrentHashMap<Bytes, Session> sessions = new ConcurrentHashMap<Bytes, Session>(k => k.hash(), (a, b) => a.compare(b) == 0);

        private GLib.List<Retransmitter> retransmitters = new GLib.List<Retransmitter>();

        private Thread<void> send_thread;

        public StreamTransmissionProtocol(Muxer muxer, Instance instance) {
            this.muxer = muxer;
            this.instance = instance;
            instance.incoming_payload.connect (handle_packet);
            send_thread = new Thread<void>("STP Network Send Thread", send_loop);
        }

        public Negotiation initialise_stream(InstanceReference target, uint8[]? in_reply_to = null) {
            // Initiate a stream with another peer
            var session_id = new uint8[16];
            UUID.generate_random(session_id);

            if(in_reply_to == null) {
                in_reply_to = EMPTY_REPLY_TO;
            }

            // Start the negotiation
            var negotiation = new Negotiation() {
                session_id = new Bytes(session_id),
                in_reply_to = new Bytes(in_reply_to),
                feature_codes = new uint8[0],
                state = NegotiationState.REQUESTED,
                remote_instance = target,
                direction = SessionDirection.EGRESS
            };
            negotiations.set(negotiation.session_id, negotiation);

            // Create the session request
            var session_request = new RequestSession(negotiation.session_id, negotiation.in_reply_to, negotiation.feature_codes);

            // Send the request
            negotiation.request_retransmitter = new MessageRetransmitter(this, negotiation.remote_instance, session_request);
            retransmitters.append(negotiation.request_retransmitter);

            // Return the negotiation object
            return negotiation;
        }

        private void handle_packet(Packet packet) {
            // We have a message, deserialise it
            var message = Message.deserialise(packet.stream);

            // What type of message do we have?
            if(message is SegmentMessage) {
                handle_segment_message((SegmentMessage)message);
                return;
            }
            if(message is RequestSession) {
                handle_request_session(packet, (RequestSession)message);
                return;
            }
            if(message is NegotiateSession) {
                handle_negotiate_session((NegotiateSession)message);
                return;
            }
            if(message is BeginSession) {
                handle_begin_session((BeginSession)message);
                return;
            }
        }

        private void handle_request_session(Packet packet, RequestSession message) {
            // Skip if we have already handled this request
            if(negotiations.has_key(message.session_id)) {
                return;
            }

            // A peer wants to initiate a session with us
            // Create a negotiation object
            var negotiation = new Negotiation() {
                session_id = message.session_id,
                in_reply_to = message.in_reply_to,
                feature_codes = message.feature_codes,
                state = NegotiationState.NEGOTIATED,
                remote_instance = packet.origin,
                direction = SessionDirection.INGRESS
            };

            // Add to negotiations
            negotiations.set(negotiation.session_id, negotiation);

            // TODO handle features

            // Construct a reply
            var reply = new NegotiateSession(negotiation.session_id, {}, message.timing);

            // Repeatedly send the negotiation
            negotiation.negotiate_retransmitter = new MessageRetransmitter(this, negotiation.remote_instance, reply);
            retransmitters.append(negotiation.negotiate_retransmitter);
        }

        private void handle_negotiate_session(NegotiateSession message) {
            // We are getting a negotiation reply from a peer
            // Do we have a negotiation open with this peer?
            if(!negotiations.has_key(message.session_id)) {
                // TODO send cleanup
                return;
            }

            // Get the negotiation
            var negotiation = negotiations.get(message.session_id);

            // Cancel the retransmitter
            if(negotiation.request_retransmitter != null){
                negotiation.request_retransmitter.cancel();
                negotiation.request_retransmitter = null;
            }

            // Set the ping value
            negotiation.ping = (get_monotonic_time()/1000) - message.reply_timing;

            // TODO features

            // Reply with a begin session message
            var reply = new BeginSession(negotiation.session_id, message.timing);

            // Send the reply
            this.retransmitters.append(new MessageRetransmitter(this, negotiation.remote_instance, reply));

            // Make sure the negotiation is in the right state
            if(negotiation.state != NegotiationState.REQUESTED) {
                return;
            }

            // Update the negotiation state
            negotiation.state = NegotiationState.ACCEPTED;

            // Setup the session
            setup_session(negotiation);
        }

        private void handle_begin_session(BeginSession message) {
            // We are getting a negotiation reply form a peer
            // Do we have a negotiation open with this peer?
            if(!negotiations.has_key(message.session_id)) {
                // TODO send cleanup
                return;
            }

            // Get the negotiation
            var negotiation = negotiations.get(message.session_id);

            // Cancel the retransmitter
            if(negotiation.negotiate_retransmitter != null){
                negotiation.negotiate_retransmitter.cancel();
                negotiation.negotiate_retransmitter = null;
            }

            // Make sure the negotiation is in the right state
            if(negotiation.state != NegotiationState.NEGOTIATED) {
                // TODO send cleanup
                return;
            }

            // Update the negotiation state
            negotiation.state = NegotiationState.ACCEPTED;

            // Set the ping value
            negotiation.ping = (get_monotonic_time()/1000) - message.reply_timing;

            // Setup the session
            setup_session(negotiation);

            // Cleanup the negotiation;
            negotiations.unset(negotiation.session_id);
        }

        private void handle_segment_message(SegmentMessage message) {
            // Do we have a session open?
            if(!sessions.has_key(message.session_id)) {
                // Skip
                return;
            }

            // Is there a valid negotiation still open?
            if(negotiations.has_key(message.session_id)) {
                // Cleanup the negotiation
                negotiations.unset(message.session_id);
            }

            // Get the session
            var session = sessions.get(message.session_id);

            // Give the session the segment
            session.process_segment(message.segment);
        }

        private void send_packet(InstanceReference target, Func<OutputStream> serialiser) throws IOError, Error{
            MemoryOutputStream stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            serialiser(stream);
            stream.flush();
            stream.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();
            muxer.send(instance, target, buffer);
        }

        private void setup_session(Negotiation negotiation) {
            // TODO feature stuff
            // Create the session object
            Session session = null;
            switch (negotiation.direction) {
                case SessionDirection.INGRESS:
                    session = new IngressSession(negotiation.remote_instance, negotiation.session_id.get_data(), negotiation.ping);
                    break;
                case SessionDirection.EGRESS:
                    session = new EgressSession(negotiation.remote_instance, negotiation.session_id.get_data(), negotiation.ping);
                    break;
            }

            // Save the session
            sessions.set(negotiation.session_id, session);

            switch (negotiation.direction) {
                case SessionDirection.INGRESS:
                    // Was this in reply to another session?
                    if(sessions.has_key(negotiation.in_reply_to)) {
                        Session regarding = sessions.get(negotiation.in_reply_to);
                        if(regarding is EgressSession) {
                            notify_app(() => ((EgressSession)regarding).received_reply((IngressSession)session));
                            break;
                        }
                        break;
                    }
                    notify_app(() => incoming_stream(new StpInputStream((IngressSession)session)));
                    break;
                case SessionDirection.EGRESS:
                    notify_app(() => negotiation.established(new StpOutputStream((EgressSession)session)));
                    break;
            }
            
        }

        private void send_loop() {
            // TODO: add a way to stop this
            while(true) {
                foreach(var session in sessions.values) {
                    if(session.has_pending_segment()) {
                        var segment = session.get_pending_segment();
                        var message = new SegmentMessage(new Bytes(session.identifier), segment);
                        send_packet(session.target, s => message.serialise(s));
                    }
                }
                foreach (var retransmitter in retransmitters) {
                    if(!retransmitter.tick()) {
                        retransmitters.remove(retransmitter);
                    }
                }
            }
        }

        private void notify_app(ThreadFunc<void> func) {
            new Thread<void>("Application notification thread", func);
        }

        private class MessageRetransmitter : Retransmitter {

            private StreamTransmissionProtocol stp;

            private Message message;

            private InstanceReference target;
    
            protected override void do_task () {
                stp.send_packet(target, s => message.serialise(s));
            }
    
            public MessageRetransmitter(StreamTransmissionProtocol stp, InstanceReference target, Message message, uint64 interval = 10000, int repeat = 12) {
                this.stp = stp;
                this.target = target;
                this.message = message;
                this.ttl = repeat;
                this.interval = interval;
            }
        }
    }

}