using LibPeer.Protocols.Mx2;

namespace LibPeer.Networks {

    public abstract class Network {
        
        public abstract Bytes get_network_identifier();

        public abstract uint16 get_mtu();

        public signal void incoming_advertisment(Advertisement advertisement);

        public signal void incoming_receiption(Receiption receiption);

        public abstract void bring_up() throws IOError, Error;

        public abstract void bring_down() throws IOError, Error;

        public abstract void advertise(InstanceReference instance_reference) throws IOError, Error;

        public abstract void send(uint8[] bytes, PeerInfo peer_info) throws IOError, Error;

        public void send_with_stream(PeerInfo peer_info, Serialiser serialiser) throws IOError, Error {
            MemoryOutputStream stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            serialiser(stream);
            stream.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();
            send(buffer, peer_info);
        }

    }

    public delegate void Serialiser(OutputStream stream) throws IOError, Error;

}