import 'package:flutter_modular/flutter_modular.dart';
import 'blocs/generator_bloc.dart';
import 'pages/generator_page.dart';

class GeneratorModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<GeneratorBloc>(GeneratorBloc.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (context) => const GeneratorPage());
  }
}
