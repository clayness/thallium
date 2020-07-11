package thallium.impl.rubis;

import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import thallium.impl.FuzzyValueCalculator;

import java.io.File;
import java.util.Iterator;
import java.util.stream.Stream;

public class RubisFuzzyValueCalculator extends FuzzyValueCalculator<RubisSystemConfig> {

    public RubisFuzzyValueCalculator(File indir, File outdir, ImmutableTriple<Double, Double, Double> weights) {
        super(indir, outdir, weights);
    }

    @Override
    public void run() {
        Iterator<String> names = Stream.of("cost", "fido", "time").iterator();
        Stream<String> filenames = Stream.of("rubis-best.txt", "rubis-exp.txt", "rubis-worst.txt");
        writeFuzzyFiles(names, filenames, (i, scanner) -> {
            int d = scanner.nextInt();
            int p = scanner.nextInt();
            int s = scanner.nextInt();
            double v = 0.0d;
            switch (i) {
                case 0: // cost
                    v = -scanner.nextDouble();
                    break;
                case 1: // fido
                    v = -scanner.nextDouble();
                    break;
                case 2: // time
                    v = -scanner.nextDouble();
                    break;
            }
            return ImmutablePair.of(new RubisSystemConfig(d, p, s), v);
        });
    }

    @Override
    protected ImmutableTriple<Double, Double, Double> getDefaultWeights() {
        return ImmutableTriple.of(0.25, 0.5, 0.25);
    }
}
