using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    public abstract class Session : Object {

        public const int64 HEARTBEAT_INTERVAL = 60;
        public const int64 HEARTBEAT_TIMEOUT = 330;

        private AsyncQueue<Segment> outgoing_segment_queue = new AsyncQueue<Segment>();

        private int64 last_heartbeat = 0;
        private Thread<bool> heart;

        public bool open { get; protected set; }

        public signal void session_closed(string reason);

        public uint8[] identifier { get; protected set; }

        public uint64 initial_ping { get; protected set; }

        public InstanceReference target { get; protected set; }

        protected Session(InstanceReference target, uint8[] session_id, uint64 ping) {
            this.target = target;
            identifier = session_id;
            initial_ping = ping;
            last_heartbeat = get_heartbeat_timestamp();

            heart = new Thread<bool>("STP Session Heartbeat", heartbeat);
        }

        public signal void has_pending_segment();

        public virtual Segment get_pending_segment() {
            return outgoing_segment_queue.pop();
        }

        protected bool segment_queue_is_clear() {
            return outgoing_segment_queue.length() == 0;
        }

        protected void queue_segment(Segment segment) {
            outgoing_segment_queue.push(segment);
            has_pending_segment();
        }

        public virtual void segment_failure(Segment segment, Error error) {
            close_session(@"Could not send segment over the network: $(error.message)");
        }

        public abstract void process_segment(Segment segment);

        protected virtual void close_session(string reason) {
            open = false;
            //  print(@"[SESSION CLOSED] $(reason)\n");
            session_closed(reason);
        }

        public virtual void close() {
            //  outgoing_segment_queue = new AsyncQueue<Segment>();
            queue_segment(new Control(ControlCommand.COMPLETE));
            close_session("Stream closed by local application");
        }

        private bool heartbeat() {
            while(open) {
                Posix.sleep((uint)HEARTBEAT_INTERVAL);
                if(get_heartbeat_timestamp() > last_heartbeat + HEARTBEAT_TIMEOUT ) {
                    queue_segment(new Control(ControlCommand.ABORT));
                    close_session("The remote peer died");
                    return false;
                }
                queue_segment(new Control(ControlCommand.HEARTBEAT));
            }

            return true;
        }

        private int64 get_heartbeat_timestamp() {
            return get_monotonic_time()/1000000;
        }

        internal virtual void begin() {}
    }

}