
using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Stp.Streams;
using Gee;

namespace LibPeer.Protocols.Stp {

    internal class Negotiation {
        public Bytes session_id { get; set; }

        public Bytes in_reply_to { get; set; }

        public uint8[] feature_codes { get; set; }

        public NegotiationState state { get; set; }

        public InstanceReference remote_instance { get; set; }

        public Retransmitter request_retransmitter { get; set; }

        public Retransmitter negotiate_retransmitter { get; set;}

        public uint64 ping { get; set; }

        public SessionDirection direction { get; set; }

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