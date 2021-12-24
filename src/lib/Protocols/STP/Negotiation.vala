
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Streams;
using Gee;

namespace LibPeer.Protocols.Stp {

    public class Negotiation : Object {
        public Bytes session_id { get; internal set; }

        public Bytes in_reply_to { get; internal set; }

        public uint8[] feature_codes { get; set; }

        public NegotiationState state { get; internal set; }

        public InstanceReference remote_instance { get; internal set; }

        internal Retransmitter request_retransmitter { get; set; }

        internal Retransmitter negotiate_retransmitter { get; set;}

        public uint64 ping { get; internal set; }

        public SessionDirection direction { get; internal set; }

        public signal void established(StpOutputStream stream);

        
    }

    public enum NegotiationState {
        REQUESTED,
        NEGOTIATED,
        ACCEPTED
    }

    public enum SessionDirection {
        INGRESS,
        EGRESS
    }

}