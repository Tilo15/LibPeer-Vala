using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Aip;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Networks;

namespace LibPeer {

    public abstract class PeerApplication : Object {

        protected ApplicationInformationProtocol discoverer { get; private set; }
        protected StreamTransmissionProtocol transport { get; private set; }
        protected Muxer muxer { get; private set; }
        protected ApplicationInformation information { get; private set; }
        protected Instance instance { get; private set; }
        protected Network[] networks { get; private set; }

        public abstract string application_namespace { get; }

        construct {
            muxer = new Muxer ();
            
            networks = configure_networks();
            discoverer = new ApplicationInformationProtocol(muxer);
            
            foreach (var network in networks) {
                network.bring_up();
                discoverer.add_network (network);
            }

            instance = muxer.create_instance (application_namespace);
            information = new ApplicationInformation.from_instance (instance);
            information.new_group_peer.connect(on_new_discovery_peer);
            instance.incoming_greeting.connect(on_peer_available);
            transport = new StreamTransmissionProtocol(muxer, instance);
            transport.incoming_stream.connect(on_incoming_stream);
            discoverer.add_application (information);
        }

        protected virtual Network[] configure_networks() {
            return new Network[] { new IPv4.IPv4("0.0.0.0", IPv4.IPv4.find_free_port("0.0.0.0")) };
        }

        protected virtual void on_new_discovery_peer() {
            find_any_peer();
        }

        protected virtual void on_peer_found(InstanceInformation peer) {
            muxer.inquire(instance, peer.instance_reference, peer.connection_methods);
        }

        protected abstract void on_peer_available(InstanceReference peer);

        protected abstract void on_incoming_stream(StpInputStream stream);

        protected Query find_any_peer() {
            var query = discoverer.find_application_instance(information);
            query.on_answer.connect(on_peer_found);
            return query;
        }

        protected Query find_resource_peer(Bytes resource_id) requires (resource_id.length == 32) {
            var query = discoverer.find_application_resource(information, resource_id);
            query.on_answer.connect(on_peer_found);
            return query;
        }

        protected Negotiation establish_stream(InstanceReference peer) throws Error {
            return transport.initialise_stream(peer);
        }

        protected Negotiation reply_to_stream(StpInputStream stream) throws Error {
            return transport.initialise_stream(stream.origin, stream.session_id);
        }


    }

}