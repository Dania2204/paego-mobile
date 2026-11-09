import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/envio.dart';
import '../../data/models/user_model.dart';
import '../../data/models/user_role.dart';
import '../../data/remote/api_client.dart';
import '../../data/repositories/envio_repository.dart';
import '../envios/envio_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _orders = 0;
  int _pending = 0;
  int _enRoute = 0;
  int _delivered = 0;
  List<Envio> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EnvioRepository.instance.envios.addListener(_calcular);
    _calcular();
    _load();
  }

  @override
  void dispose() {
    EnvioRepository.instance.envios.removeListener(_calcular);
    super.dispose();
  }

  void _calcular() {
    if (!mounted) return;
    final envios = EnvioRepository.instance.envios.value;
    setState(() {
      _orders = envios.where((e) => e.estado.esActivo).length;
      _pending = envios.where((e) => e.estado == EstadoEnvio.asignado).length;
      _enRoute = envios.where((e) => e.estado == EstadoEnvio.enTransito).length;
      _delivered = envios
          .where(
            (e) =>
                e.estado == EstadoEnvio.entregado ||
                e.estado == EstadoEnvio.conNovedad,
          )
          .length;
      // Primero los activos, luego los más recientes.
      final ordenados = [...envios]
        ..sort((a, b) {
          if (a.estado.esActivo != b.estado.esActivo)
            return a.estado.esActivo ? -1 : 1;
          return (b.programadoPara ?? DateTime(0)).compareTo(
            a.programadoPara ?? DateTime(0),
          );
        });
      _recent = ordenados.take(5).toList();
      if (envios.isNotEmpty) _loading = false;
    });
  }

  Future<void> _load() async {
    try {
      await EnvioRepository.instance.refrescar();
    } on SinConexionException {
      // Se muestran los datos guardados en el teléfono.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? S.text('saludo.manana', 'Buenos días', 'Good morning')
        : hour < 18
        ? S.text('saludo.tarde', 'Buenas tardes', 'Good afternoon')
        : S.text('saludo.noche', 'Buenas noches', 'Good evening');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: PaeColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Hero AppBar ──────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: PaeColors.gradStart,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: PaeColors.heroGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(
                                    initials: user.initials,
                                    photoPath: user.photoPath,
                                    radius: 24,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$greeting,',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 13,
                                          fontFamily: PaeTypography.fontBody,
                                        ),
                                      ),
                                      Text(
                                        user.fullName.split(' ').first,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: PaeTypography.fontDisplay,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user.role.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: PaeTypography.fontBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            S.text(
                              'dashboard.title',
                              '${S.appName} Dashboard',
                              '${S.appName} Dashboard',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: PaeTypography.fontDisplay,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            S.appTagline,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontFamily: PaeTypography.fontBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: PaeColors.primary),
                ),
              )
            else ...[
              // ── Stats grid ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      StatCard(
                        label: S.dashboardActiveDeliveries,
                        value: '$_orders',
                        icon: Icons.local_shipping_rounded,
                        color: PaeColors.primary,
                      ),
                      StatCard(
                        label: S.dashboardPendingOrders,
                        value: '$_pending',
                        icon: Icons.schedule_rounded,
                        color: PaeColors.statusPending,
                      ),
                      StatCard(
                        label: S.text(
                          'envio.estado.en_transito',
                          'En tránsito',
                          'In transit',
                        ),
                        value: '$_enRoute',
                        icon: Icons.directions_car_rounded,
                        color: PaeColors.statusEnRoute,
                      ),
                      StatCard(
                        label: S.text(
                          'envio.estado.entregados',
                          'Entregados',
                          'Delivered',
                        ),
                        value: '$_delivered',
                        icon: Icons.check_circle_rounded,
                        color: PaeColors.statusDelivered,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Quick Actions ────────────────────────────────────────
              SliverToBoxAdapter(
                child: SectionHeader(title: S.dashboardQuickActions),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickActions(user: user),
                ),
              ),

              // ── Recent deliveries ────────────────────────────────────
              SliverToBoxAdapter(
                child: SectionHeader(title: S.dashboardRecentActivity),
              ),

              if (_recent.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 56,
                            color: PaeColors.inactive,
                          ),
                          SizedBox(height: 12),
                          Text(
                            S.orderNoOrders,
                            style: const TextStyle(
                              color: PaeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => EnvioTile(
                      envio: _recent[i],
                      onTap: () => mostrarDetalleEnvio(ctx, _recent[i], user),
                    ),
                    childCount: _recent.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Buttons ──────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final actions = <_QA>[
      if (user.role.canCreateOrders)
        _QA(
          Icons.add_road_rounded,
          S.text('quick.new_order', 'Nuevo pedido', 'New Order'),
          PaeColors.secondary,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  S.text(
                    'quick.goto_map_deliveries',
                    'Ve a Mapa para gestionar entregas',
                    'Go to Map tab to manage deliveries',
                  ),
                ),
              ),
            );
          },
        ),
      if (user.role.canSubmitReport)
        _QA(
          Icons.assignment_add,
          S.text('quick.new_report', 'Nuevo informe', 'New Report'),
          PaeColors.success,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  S.text(
                    'quick.goto_reports',
                    'Ve a Informes',
                    'Go to Reports tab',
                  ),
                ),
              ),
            );
          },
        ),
      if (user.role.canAddSchoolLocation)
        _QA(
          Icons.add_location_alt_rounded,
          S.text(
            'quick.add_school_pin',
            'Agregar pin de escuela',
            'Add School Pin',
          ),
          PaeColors.info,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  S.text(
                    'quick.goto_map_school',
                    'Ve a Mapa para agregar la ubicacion de la escuela',
                    'Go to Map tab to add school location',
                  ),
                ),
              ),
            );
          },
        ),
      if (user.role.canManageUsers)
        _QA(
          Icons.person_add_rounded,
          S.text('quick.add_personnel', 'Agregar personal', 'Add Personnel'),
          PaeColors.primaryLight,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  S.text(
                    'quick.goto_personnel',
                    'Ve a Personal',
                    'Go to Personnel tab',
                  ),
                ),
              ),
            );
          },
        ),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _QATile(qa: a),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QA {
  const _QA(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QATile extends StatelessWidget {
  const _QATile({required this.qa});
  final _QA qa;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: qa.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: qa.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qa.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(qa.icon, color: qa.color, size: 28),
            const SizedBox(height: 8),
            Text(
              qa.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qa.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: PaeTypography.fontBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
