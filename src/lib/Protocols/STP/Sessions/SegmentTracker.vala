using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    public class SegmentTracker {

        public int pending_segment_count { get; private set; }

        public int complete_segment_count { get; private set; }

        public signal void on_complete();

        public signal void on_error(IOError e);

        internal void add_segment() {
            pending_segment_count++;
        }

        internal void complete_segment() {
            complete_segment_count++;
            if(complete_segment_count == pending_segment_count) {
                on_complete();
            }
        }

        internal void fail(IOError e) {
            if(complete_segment_count < pending_segment_count) {
                on_error(e);
            }
        }

    }

}