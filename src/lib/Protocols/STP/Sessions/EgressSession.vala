using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Util;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    const int SEGMENT_PAYLOAD_SIZE = 14000;
    const int METRIC_WINDOW_SIZE = 4;
    const int64 MAX_WINDOW_SIZE = 9223372036854775808;

    public class EgressSession : Session {

        private ConcurrentHashMap<uint64?, Payload> in_flight = new ConcurrentHashMap<uint64?, Payload>(i => (uint)i, (a, b) => a == b);
        private int in_flight_count = 0;

        private ConcurrentHashMap<uint64?, SegmentTracker> segment_trackers = new ConcurrentHashMap<uint64?, SegmentTracker>(i => (uint)i, (a, b) => a == b);

        private ArrayList<uint64?> segment_trips = new ArrayList<uint64?>();

        protected AsyncQueue<Payload> payload_queue = new AsyncQueue<Payload>();

        private int redundant_resends = 0;
        private uint64 window_size = METRIC_WINDOW_SIZE;
        private uint64 best_ping = 10000;
        private uint64 worst_ping = 0;
        private int64 adjustment_delta = 0;
        private uint64 last_send = 0;

        private uint64 next_sequence_number = 0;

        public signal void received_reply(StpInputStream stream);

        public EgressSession(InstanceReference target, uint8[] session_id, uint64 ping) {
            base(target, session_id, ping);
            best_ping = ping;
            worst_ping = ping;
            open = true;
        }

        public override void process_segment(Segment segment) {
            // We have received a segment from the muxer
            // Determine the segment type
            if(segment is Acknowledgement) {
                handle_acknowledgement((Acknowledgement)segment);
                return;
            }
            if(segment is Control) {
                handle_control((Control)segment);
                return;
            }
            
        }

        private void handle_control(Control segment) {
            // We have a control segment, what is it telling us?
            switch(segment.command) {
                case ControlCommand.COMPLETE:
                    close_session("The remote peer completed the stream");
                    break;
                case ControlCommand.ABORT:
                    close_session("The stream was aborted by the remote peer");
                    break;
                case ControlCommand.NOT_CONFIGURED:
                    close_session("The remote peer claims to not know about this session");
                    break;
            }
        }

        private int64 window_time = 0;
        private int64 last_window_time = 0;
        private uint64 last_window_size = 0;

        private void handle_acknowledgement(Acknowledgement segment) {
            // Is this segment still in-flight?
            if(!in_flight.has_key(segment.sequence_number)) {
                //  print(@"***Redundant resend (segment $(segment.sequence_number))\n");
                // No, we must have resent redundantly
                redundant_resends++;
                return;
            }
            
            // We have an acknowledgement segment, remove payload segment from in-flight
            in_flight.unset(segment.sequence_number);
            in_flight_count--;

            // Do we have a tracking object for this?
            if(segment_trackers.has_key(segment.sequence_number)) {
                // Yes, notify it
                segment_trackers.get(segment.sequence_number).complete_segment();
            }

            // What was the time difference?
            var round_trip = (get_monotonic_time()/1000) - segment.timing;

            // Are we currently at metric window size?
            //  if(window_size == METRIC_WINDOW_SIZE) {
                // Yes, add round trip time to the list
                segment_trips.add(round_trip);

                // Do we have a sample?
                if(segment_trips.size >= METRIC_WINDOW_SIZE) {
                    var current_window_time = get_monotonic_time() - window_time;
                    // Update the ping based on the average of the metric segments
                    uint64 average = segment_trips[0];
                    foreach (var ping in segment_trips) {
                        average = (average + ping)/2;
                    }
                    
                    var last = (last_window_size / (double)uint64.max(last_window_time, 1));
                    var current = (window_size / (double)uint64.max(current_window_time, 1));

                    last_window_size = window_size;

                    adjust_window_size(last, current);




                    best_ping = uint64.min(best_ping, average);
                    worst_ping = uint64.max(worst_ping, average);
                    segment_trips.clear();
                    last_window_time = current_window_time;
                    window_time = get_monotonic_time();
                }
            //  }
            //  else {
            //      adjust_window_size(round_trip);
            //  }
            
        }

        public override bool has_pending_segment() {
            // Do we have segments to queue, and room in our window to queue them?
            if(payload_queue.length() > 0 && in_flight_count < window_size) {
                // Yes, do it
                var segment = payload_queue.pop();
                in_flight.set(segment.sequence_number, segment);
                in_flight_count++;
                outgoing_segment_queue.push(segment);
            }

            // Calculate a maximum time value for segments eligable to be resent
            uint64 max_time = (get_monotonic_time()/1000) - (uint64)(worst_ping + (redundant_resends * 10));
            
            // Do we have any in-flight segments to resend?
            foreach (var segment in in_flight.values) {
                // Is the segment timing value less than the max time?
                if(segment.timing != 0 && segment.timing < max_time) {
                    print(@"***Resend segment $(segment.sequence_number)\n");
                    // Resend it
                    segment.reset_timing();
                    queue_segment(segment);
                    break;
                }
            }

            return base.has_pending_segment();
        }

        public override Segments.Segment get_pending_segment() {
            last_send = get_monotonic_time() / 1000;
            return base.get_pending_segment();
        }

        private void adjust_window_size(double last, double current) {
            //  print(@"current = $(current); compare = $(last);\n");

            if(last > current) {
                print("\t++\n");
                if(adjustment_delta < 0) {
                    adjustment_delta = 1;
                }
                else {
                    adjustment_delta ++;
                }
            }
            else if(current > last) {
                print("\t  --\n");
                if(adjustment_delta > 0) {
                    adjustment_delta = -1;
                }
                else {
                    adjustment_delta --;
                }
            }
            else {
                print("\t   ==\n");
                adjustment_delta = 0;
            }
            adjustment_delta = int64.min(adjustment_delta, 4);
            adjustment_delta = int64.max(adjustment_delta, -4);
            window_size += adjustment_delta;

            // Is the window size now less than the metric size?
            if(window_size < METRIC_WINDOW_SIZE) {
                // Yes, reset it to the metric size
                window_size = METRIC_WINDOW_SIZE;
            }
            // Is the window size now bigger than the max window size?
            if(window_size > MAX_WINDOW_SIZE) {
                // Yes, cap it
                window_size = MAX_WINDOW_SIZE;
            }
            print(@"WINDOW SIZE: $(window_size)\n");
        }

        protected override void close_session(string reason) {
            base.close_session(reason);
            payload_queue = new AsyncQueue<Payload>();
            in_flight.clear();
            var error = new IOError.CONNECTION_CLOSED("The session was closed before the segment was sent");
            foreach (var tracker in segment_trackers.values) {
                tracker.fail(error);
            }
        }

        public SegmentTracker queue_send(uint8[] data) throws IOError{
            // Is the stream open?
            if(!open) {
                throw new IOError.CLOSED("Cannot send data: The stream is closed");
            }

            // Create a segment tracker
            var tracker = new SegmentTracker();

            // Get lock on payload queue
            lock(payload_queue) {
                // Calculate number of segments needed
                int segment_count = data.length / SEGMENT_PAYLOAD_SIZE;
                if (data.length % SEGMENT_PAYLOAD_SIZE != 0) {
                    segment_count++;
                }

                if(segment_count == 0) {
                    throw new IOError.INVALID_DATA("No data to send");
                }

                for(int i = 0; i < segment_count; i++) {
                    // TODO run through features
                    segment_trackers.set(next_sequence_number, tracker);
                    tracker.add_segment();
                    int payload_size = int.min(data.length, (i+1)*SEGMENT_PAYLOAD_SIZE);
                    print(@"data.length: $(data.length); i: $(i); SEGMENT_PAYLOAD_SIZE: $(SEGMENT_PAYLOAD_SIZE); payload_size: $(payload_size)\n");
                    payload_queue.push(new Payload(next_sequence_number, data[i*SEGMENT_PAYLOAD_SIZE:payload_size].copy()));
                    next_sequence_number ++;
                }
            }

            // Return the tracker
            return tracker;
        }

    }

}