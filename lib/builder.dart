import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/relax_table_generator.dart';

Builder relaxOrmBuilder(BuilderOptions options) =>
    SharedPartBuilder([RelaxTableGenerator()], 'relax_orm');
