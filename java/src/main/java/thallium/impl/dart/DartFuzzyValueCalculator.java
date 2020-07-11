package thallium.impl.dart;

import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.FuzzyValueCalculator;

import java.io.File;
import java.util.Iterator;
import java.util.stream.Stream;

public class DartFuzzyValueCalculator extends FuzzyValueCalculator<DartSystemConfig> {
    public DartFuzzyValueCalculator(File srcDir, File outDir, ImmutableTriple<Double, Double, Double> weights) {
        super(srcDir, outDir, weights);
    }

    @Override
    public void run() {
        Iterator<String> names = Stream.of("detected", "distance").iterator();
        Stream<String> filenames = Stream.of("dart-best.txt", "dart-exp.txt", "dart-worst.txt");
        writeFuzzyFiles(names, filenames, (i, scanner) -> {
            int a = scanner.nextInt();
            int f = scanner.nextInt();
            int l = scanner.nextInt();
            double v = scanner.nextDouble();
            return ImmutablePair.of(new DartSystemConfig(a, f, false, (l >= 0.0) ? l : 0, (l <= 0.0) ? -l : 0,
                    0, 0), v);
        });
    }

    @Override
    public ImmutableTriple<Double, Double, Double> getDefaultWeights() {
        return ImmutableTriple.of(0.0, 0.5, 0.5);
    }
}
