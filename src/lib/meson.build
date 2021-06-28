vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('vala').find_library('uuid', dirs: vapi_dir),
    meson.get_compiler('c').find_library('uuid'),
    meson.get_compiler('vala').find_library('libsodium', dirs: vapi_dir),
    meson.get_compiler('c').find_library('sodium')
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
sources += files('Protocols/MX2/Muxer.vala')
sources += files('Protocols/MX2/Frame.vala')
sources += files('Protocols/MX2/Inquiry.vala')
sources += files('Protocols/MX2/Instance.vala')
sources += files('Protocols/MX2/InstanceAccessInfo.vala')
sources += files('Protocols/MX2/InstanceReference.vala')
sources += files('Protocols/MX2/Packet.vala')
sources += files('Protocols/MX2/PathInfo.vala')
sources += files('Protocols/MX2/PathStrategy.vala')
sources += files('Util/ByteComposer.vala')
sources += files('Util/QueueCommand.vala')
sources += files('Util/ThreadTimer.vala')

libpeer = library('peer', sources, dependencies: dependencies)
libpeer_dep = declare_dependency(link_with: libpeer, include_directories: include_directories('.'))
