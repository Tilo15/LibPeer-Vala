using LibPeer.Protocols.Mx2;

namespace LibPeer.Networks {

    public abstract class Network {
        
        public abstract Bytes get_network_identifier();

        public signal void incoming_advertisment(Advertisement advertisement);

        public signal void incoming_receiption(Receiption receiption);

        public abstract void bring_up() throws IOError, Error;

        public abstract void bring_down() throws IOError, Error;

        public abstract void advertise(InstanceReference instance_reference) throws IOError, Error;

        public abstract void send(Bytes bytes, PeerInfo peer_info) throws IOError, Error;

    }

}