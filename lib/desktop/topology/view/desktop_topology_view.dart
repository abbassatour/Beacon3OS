// lib/desktop/topology/view/desktop_topology_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_cubit.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_state.dart';
import 'package:beacon_os/desktop/topology/widgets/node_inspector_panel.dart';
import 'package:beacon_os/desktop/topology/widgets/spatial_grid_canvas.dart';
import 'package:beacon_os/desktop/topology/widgets/topology_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopTopologyView extends StatelessWidget {
  const DesktopTopologyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopTopologyCubit(
        topologyRepository: context.read<TopologyRepository>(),
        // ✅ حقن VaultSyncCoordinator لبث تحديثات الفضاء عبر LAN
        vaultSyncCoordinator: context.read<VaultSyncCoordinator>(),
      ),
      child: const _DesktopTopologyContent(),
    );
  }
}

class _DesktopTopologyContent extends StatelessWidget {
  const _DesktopTopologyContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopTopologyCubit, DesktopTopologyState>(
      builder: (context, state) {
        if (state.status == TopologyStatus.loading && state.nodes.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopologyHeader(state: state),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SpatialGridCanvas(state: state),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: NodeInspectorPanel(state: state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}