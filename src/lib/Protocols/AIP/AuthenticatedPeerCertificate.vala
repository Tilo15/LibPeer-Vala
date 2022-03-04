
namespace LibPeer.Protocols.Aip {

    public class AuthenticatedPeerCertificate : InstanceInformation {

        private uint8[] raw { get; set; }
        public uint8[] challenge_data { get; private set; }

        public AuthenticatedPeerCertificate.from_challenge(AuthenticatedPeerChallenge challenge, AuthenticatedPeerKey key, InstanceInformation info)
        requires (challenge.identity.public_key == key.public_key) {
            copy_from(info);
            challenge_data = challenge.challenge_data;
            serialise_sign(key);
        }

        private void serialise_sign(AuthenticatedPeerKey key) {
            var stream = new MemoryOutputStream(null, GLib.realloc, GLib.free);
            var dos = new DataOutputStream(stream);

            base.serialise(stream);
            dos.write(challenge_data);

            dos.close();
            uint8[] buffer = stream.steal_data();
            buffer.length = (int)stream.get_data_size();

            raw = buffer.copy();
        }

        public override void serialise(OutputStream stream) {
            stream.write(raw);
        }

        public AuthenticatedPeerCertificate.verify(uint8[] data, AuthenticatedPeerIdentity identity) {
            var verified = identity.verify(data);
            var stream = new MemoryInputStream.from_data(verified);
            var dis = new DataInputStream(stream);

            fill_from_stream(stream);
            challenge_data = dis.read_bytes(AuthenticatedPeerChallenge.CHALLENGE_LENGTH).get_data();

            dis.close();
        }
    }


}