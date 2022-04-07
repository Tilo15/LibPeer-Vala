vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--disable-warnings', '--enable-checking','--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('vala').find_library('uuid', dirs: vapi_dir),
    meson.get_compiler('c').find_library('uuid'),
    meson.get_compiler('vala').find_library('libsodium', dirs: vapi_dir),
    meson.get_compiler('c').find_library('sodium'),
    meson.get_compiler('c').find_library('m')
]

sources = files('Networks/Advertisement.vala')
sources += files('Networks/Network.vala')
sources += files('Networks/PeerInfo.vala')
sources += files('Networks/UnknownPeerInfo.vala')
sources += files('Networks/Receiption.vala')
sources += files('Networks/Simulation/NetSimPeerInfo.vala')
sources += files('Networks/Simulation/Conduit.vala')
sources += files('Networks/Simulation/NetSim.vala')
sources += files('Networks/Simulation/Packet.vala')
sources += files('Networks/IPv4/IPv4.vala')
sources += files('Networks/IPv4/IPv4PeerInfo.vala')
sources += files('Protocols/MX2/Muxer.vala')
sources += files('Protocols/MX2/Frame.vala')
sources += files('Protocols/MX2/Inquiry.vala')
sources += files('Protocols/MX2/Instance.vala')
sources += files('Protocols/MX2/InstanceAccessInfo.vala')
sources += files('Protocols/MX2/InstanceReference.vala')
sources += files('Protocols/MX2/Packet.vala')
sources += files('Protocols/MX2/PathInfo.vala')
sources += files('Protocols/MX2/PathStrategy.vala')
sources += files('Protocols/MX2/Fragment.vala')
sources += files('Protocols/MX2/Fragmenter.vala')
sources += files('Protocols/MX2/Assembler.vala')
sources += files('Protocols/MX2/Router/Frame.vala')
sources += files('Protocols/MX2/Router/Muxer.vala')
sources += files('Protocols/MX2/Router/InstanceResolver.vala')
sources += files('Protocols/STP/StreamTransmissionProtocol.vala')
sources += files('Protocols/STP/Negotiation.vala')
sources += files('Protocols/STP/Retransmitter.vala')
sources += files('Protocols/STP/Sessions/Session.vala')
sources += files('Protocols/STP/Sessions/IngressSession.vala')
sources += files('Protocols/STP/Sessions/EgressSession.vala')
sources += files('Protocols/STP/Sessions/SegmentTracker.vala')
sources += files('Protocols/STP/Segments/Segment.vala')
sources += files('Protocols/STP/Segments/Acknowledgement.vala')
sources += files('Protocols/STP/Segments/Control.vala')
sources += files('Protocols/STP/Segments/Payload.vala')
sources += files('Protocols/STP/Messages/Message.vala')
sources += files('Protocols/STP/Messages/BeginSession.vala')
sources += files('Protocols/STP/Messages/NegotiateSession.vala')
sources += files('Protocols/STP/Messages/RequestSession.vala')
sources += files('Protocols/STP/Messages/SegmentMessage.vala')
sources += files('Protocols/STP/Streams/InputStream.vala')
sources += files('Protocols/STP/Streams/OutputStream.vala')
sources += files('Protocols/AIP/ApplicationInformationProtocol.vala')
sources += files('Protocols/AIP/AipCapabilities.vala')
sources += files('Protocols/AIP/ApplicationInformation.vala')
sources += files('Protocols/AIP/QueryGroup.vala')
sources += files('Protocols/AIP/Query.vala')
sources += files('Protocols/AIP/InstanceInformation.vala')
sources += files('Protocols/AIP/Answer.vala')
sources += files('Protocols/AIP/Request.vala')
sources += files('Protocols/GDP/GeneralDiscoveryProtocol.vala')
sources += files('Protocols/GDP/QueryBase.vala')
sources += files('Protocols/GDP/Query.vala')
sources += files('Protocols/GDP/WrappedQuery.vala')
sources += files('Protocols/GDP/QuerySummary.vala')
sources += files('Protocols/GDP/Challenge.vala')
sources += files('Protocols/GDP/Answer.vala')
sources += files('Protocols/GDP/Application.vala')
sources += files('Util/ByteComposer.vala')
sources += files('Util/QueueCommand.vala')
sources += files('Util/ThreadTimer.vala')
sources += files('Util/ConcurrentHashMap.vala')
sources += files('Util/TimeoutMap.vala')
sources += files('Util/Streams.vala')
sources += files('Application/Application.vala')
sources += files('Routing/RouterDiscovery.vala')
sources += files('Routing/Router.vala')
sources += files('Routing/GdpInstanceResolver.vala')

libpeer = shared_library('libpeer', sources,
    name_prefix: '',
    dependencies: dependencies,
    install: true,
    vala_gir: 'LibPeer-1.0.gir',
    install_dir: [true, true, true, true]
)
libpeer_dep = declare_dependency(link_with: libpeer, include_directories: include_directories('.'))

pkg = import('pkgconfig')
pkg.generate(libpeer,
    version : '0.1',
    name : 'libpeer',)
    
g_ir_compiler = find_program('g-ir-compiler')
custom_target('libpeer typelib', command: [g_ir_compiler, '--shared-library=libpeer.so', '--output', '@OUTPUT@', meson.current_build_dir() / 'LibPeer-1.0.gir'],
              output: 'LibPeer-1.0.typelib',
              depends: libpeer,
              install: true,
              install_dir: get_option('libdir') / 'girepository-1.0')