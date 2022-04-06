using LibPeer.Protocols.Mx2;
using LibPeer.Protocols.Gdp;
using LibPeer.Protocols.Stp;
using LibPeer.Protocols.Stp.Streams;
using LibPeer.Networks;

namespace LibPeer {

    public abstract class PeerApplication : Object {

        protected GeneralDiscoveryProtocol discoverer { get; private set; }
        protected GdpApplication information { get; private set; }
        protected StreamTransmissionProtocol transport { get; private set; }
        protected Muxer muxer { get; private set; }
        protected Instance instance { get; private set; }
        protected Network[] networks { get; private set; }

        protected bool is_initialised { get; private set; }

        construct {
            is_initialised = false;
            muxer = new Muxer ();
        }
        
        protected void initialise(string application_namespace, Network[]? network_list = null) {
            lock(is_initialised) {
                if(is_initialised) {
                    warning("Application already initialised, skipping");
                    return;
                }

                discoverer = new GeneralDiscoveryProtocol(muxer);
                networks = network_list ?? new Network[] { IPv4.IPv4.automatic() };
                
                foreach (var network in networks) {
                    network.bring_up();
                    discoverer.add_network (network);
                }
    
                instance = muxer.create_instance (application_namespace);
                instance.incoming_greeting.connect(on_peer_available);
                transport = new StreamTransmissionProtocol(muxer, instance);
                transport.incoming_stream.connect(on_incoming_stream);
                information = discoverer.add_application (instance);
                information.query_answered.connect(on_query_answer);
                information.challenged.connect(on_challenge);
                is_initialised = true;
            }
        }

        protected void inquire(Answer answer) {
            muxer.inquire(instance, answer.instance_reference, answer.connection_methods);
        }

        protected virtual void on_query_answer(Answer answer) {
            inquire(answer);
        }

        protected virtual void on_challenge(GLib.Bytes resource_identifier, Challenge challenge) {
            warning("Received a challange for a resource, but no handler has been implemented. Ignoring.");
        }

        protected abstract void on_peer_available(InstanceReference peer);

        protected abstract void on_incoming_stream(StpInputStream stream);

        protected void search_for_any_peer() throws Error {
            discoverer.query_general(information);
        }

        protected void search_for_resource_peer(Bytes resource_identifier, Challenge challenge, uint8[]? private_data = null) throws Error {
            discoverer.query_resource(information, resource_identifier.get_data(), challenge, private_data);
        }

        protected Negotiation establish_stream(InstanceReference peer) throws Error {
            return transport.initialise_stream(peer);
        }

        protected Negotiation reply_to_stream(StpInputStream stream) throws Error {
            return transport.initialise_stream(stream.origin, stream.session_id);
        }


    }

}