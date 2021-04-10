project('High Level Peer Communication Engine Daemon', 'vala', 'c')

vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('vala').find_library('uuid', dirs: vapi_dir),
    meson.get_compiler('c').find_library('uuid')
]

sources = files('Daemon.vala')
sources += files('Networks/Advertisement.vala')
sources += files('Networks/Network.vala')
sources += files('Networks/PeerInfo.vala')
sources += files('Networks/UnknownPeerInfo.vala')
sources += files('Networks/Receiption.vala')
sources += files('Networks/Simulation/NetSimPeerInfo.vala')
sources += files('Networks/Simulation/Conduit.vala')
sources += files('Networks/Simulation/NetSim.vala')
sources += files('Networks/Simulation/Packet.vala')
sources += files('Protocols/MX2/InstanceReference.vala')
sources += files('Util/QueueCommand.vala')

executable('hlpced', sources, dependencies: dependencies)
