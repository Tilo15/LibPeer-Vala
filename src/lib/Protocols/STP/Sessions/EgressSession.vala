using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Segments;
using LibPeer.Util;
using Gee;

namespace LibPeer.Protocols.Stp.Sessions {

    const int SEGMENT_PAYLOAD_SIZE = 16384;
    const int METRIC_WINDOW_SIZE = 4;
    const int MAX_WINDOW_SIZE = 65536;

    public class EgressSession : Session {

        private ConcurrentHashMap<uint64?, Payload> in_flight = new ConcurrentHashMap<uint64?, Payload>(i => (uint)i, (a, b) => a == b);
        private int in_flight_count = 0;

        private ConcurrentHashMap<uint64?, SegmentTracker> segment_trackers = new ConcurrentHashMap<uint64?, SegmentTracker>(i => (uint)i, (a, b) => a == b);

        private ArrayList<uint64?> segment_trips = new ArrayList<uint64?>();

        protected AsyncQueue<Payload> payload_queue = new AsyncQueue<Payload>();

        private int redundant_resends = 0;
        private int window_size = METRIC_WINDOW_SIZE;
        private uint64 best_ping = 0;
        private uint64 worst_ping = 0;
        private int adjustment_delta = 0;
        private uint64 last_send = 0;

        private uint64 next_sequence_number = 0;

        public signal void received_reply(IngressSession session);

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
            if(window_size == METRIC_WINDOW_SIZE) {
                // Yes, add round trip time to the list
                segment_trips.add(round_trip);

                // Do we have a sample?
                if(segment_trips.size >= METRIC_WINDOW_SIZE) {
                    // Update the ping based on the average of the metric segments
                    uint64 avarage = 0;
                    foreach (var ping in segment_trips) {
                        avarage += ping;
                    }
                    avarage = avarage / segment_trips.size;
                    best_ping = avarage;

                    adjust_window_size(round_trip);
                }
                else {
                    adjust_window_size(round_trip);
                }
            }
            
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
            uint64 max_time = (get_monotonic_time()/1000) - 5000; //(uint64)((worst_ping * Math.log10(redundant_resends + 10) * window_size) * 1000);
            
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

        private void adjust_window_size(uint64 last_trip) {
            uint64 last_trip_metric = last_trip / 1000;

            // Is this the worst we have had?
            if(worst_ping < last_trip) {
                // Update worst ping metric
                worst_ping = last_trip;
            }

            // Has the trip time gotten longer?
            if (last_trip_metric > best_ping) {
                // Yes, were we previously increasing the window size?
                if(adjustment_delta > 0) {
                    // Yes, stop increasing it
                    adjustment_delta = 0;
                }
                // Were we keeping the window size consistant?
                else if(adjustment_delta == 0) {
                    adjustment_delta = -1;
                }
                // Were we previously decreasing it?
                else if(adjustment_delta < 0) {
                    adjustment_delta *= 2;
                }
            }
            // Did the trip get shorter or stay the same?
            else if (last_trip_metric <= best_ping) {
                // Yes, were we previously increasing the window size?
                if(adjustment_delta > 0) {
                    // Yes, increase it some more
                    adjustment_delta *= 2;
                }
                // Were we previously keeping the window size consistant?
                if(adjustment_delta == 0) {
                    // Yes, start incrrasing ituint64? key
                    adjustment_delta = 1;
                }
                // Were we previosuly decreasing the window size?
                if(adjustment_delta < 0) {
                    // Yes, stop
                    adjustment_delta = 0;
                }
            }

            // Apply the delta
            window_size += adjustment_delta;

            // Is the window size now less than the metric size?
            if(window_size < METRIC_WINDOW_SIZE) {
                // Yes, reset it to the metric size
                window_size = METRIC_WINDOW_SIZE;

                // Update the delta so when we have our metric we can start increasing again
                adjustment_delta = 1;

                // Clear out our trip metrics
                segment_trips.clear();
            }
            // Is the window size now bigger than the max window size?
            if(window_size > MAX_WINDOW_SIZE) {
                // Yes, cap it
                window_size = MAX_WINDOW_SIZE;
            }
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
                    int payload_size = data.length < (i+1)*SEGMENT_PAYLOAD_SIZE ? data.length : (i+1)*SEGMENT_PAYLOAD_SIZE;
                    payload_queue.push(new Payload(next_sequence_number, data[i*SEGMENT_PAYLOAD_SIZE:payload_size]));
                    next_sequence_number ++;
                }
            }

            // Return the tracker
            return tracker;
        }

    }

}