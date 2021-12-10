using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    public abstract class Session : Object {

        protected AsyncQueue<Segment> outgoing_segment_queue = new AsyncQueue<Segment>();

        public bool open { get; protected set; }

        public signal void session_closed(string reason);

        public uint8[] identifier { get; protected set; }

        public uint64 initial_ping { get; protected set; }

        public InstanceReference target { get; protected set; }

        protected Session(InstanceReference target, uint8[] session_id, uint64 ping) {
            this.target = target;
            identifier = session_id;
            initial_ping = ping;
        }

        public virtual bool has_pending_segment() {
            return outgoing_segment_queue.length() > 0;
        }

        public virtual Segment get_pending_segment() {
            return outgoing_segment_queue.pop();
        }

        protected void queue_segment(Segment segment) {
            outgoing_segment_queue.push(segment);
        }

        public abstract void process_segment(Segment segment);

        protected virtual void close_session(string reason) {
            open = false;
            print(@"[SESSION CLOSED] $(reason)\n");
            session_closed(reason);
        }

        public virtual void close() {
            //  outgoing_segment_queue = new AsyncQueue<Segment>();
            queue_segment(new Control(ControlCommand.COMPLETE));
            close_session("Stream closed by local application");
        }
    }

}