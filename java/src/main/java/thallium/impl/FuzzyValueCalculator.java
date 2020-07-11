package thallium.impl;

import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;

import java.io.File;
import java.io.PrintWriter;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public abstract class FuzzyValueCalculator<C extends SystemConfig> implements Runnable {

    private final File srcDir;
    private final File outDir;
    private final ImmutableTriple<Double, Double, Double> weights;

    protected FuzzyValueCalculator(File srcDir, File outDir, ImmutableTriple<Double, Double, Double> weights) {
        this.weights = weights;
        this.srcDir = srcDir;
        this.outDir = outDir;
        //noinspection ResultOfMethodCallIgnored
        outDir.mkdirs();
    }

    private ImmutableTriple<Double, Double, Double> getWeights() {
        return this.weights == null ? getDefaultWeights() : weights;
    }

    protected ImmutableTriple<Double, Double, Double> getDefaultWeights() {
        return ImmutableTriple.of(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0);
    }

    private Map<C, FuzzyValue> parseSection(List<BoundsReader<C>.BoundsSection> sections) {
        HashMap<C, FuzzyValue> map = new HashMap<>();
        while (true) {
            try {
                List<ImmutablePair<C, Double>> configs = sections.stream()
                        .map(BoundsReader.BoundsSection::nextConfig)
                        .collect(Collectors.toList());
                if (configs.stream().anyMatch(Objects::isNull))
                    break;
                if (!configs.stream().map(ImmutablePair::getRight).allMatch(Double::isFinite))
                    continue;
                double p = Math.abs(configs.get(2).right - configs.get(1).right);
                double l = configs.get(1).right;
                double o = Math.abs(configs.get(1).right - configs.get(0).right);
                FuzzyValue fv = new FuzzyValue(p, l, o, getWeights());
                map.put(configs.get(0).left, fv);
            } catch (UnsupportedOperationException e) {
                /* no-op */
            }
        }
        return map;
    }

    private AutoCloseable closeAll(List<? extends AutoCloseable> values) {
        return () -> {
            for (AutoCloseable v : values)
                v.close();
        };
    }

    private Map<C, FuzzyValue> normalize(Map<C, FuzzyValue> map) {
        double nisM, pisM, nisO, pisO, nisP, pisP;
        pisM = pisO = pisP = Double.NEGATIVE_INFINITY;
        nisM = nisO = nisP = Double.POSITIVE_INFINITY;
        for (FuzzyValue fv : map.values()) {
            pisM = Math.max(pisM, fv.getMostLikely());
            nisM = Math.min(nisM, fv.getMostLikely());
            pisO = Math.max(pisO, fv.getOptimistic());
            nisO = Math.min(nisO, fv.getOptimistic());
            pisP = Math.max(pisP, -fv.getPessimistic());
            nisP = Math.min(nisP, -fv.getPessimistic());
        }
        pisP = Math.abs(pisP);
        nisP = Math.abs(nisP);

        Map<C, FuzzyValue> retval = new HashMap<>();
        for (Map.Entry<C, FuzzyValue> entry : map.entrySet()) {
            FuzzyValue curr = entry.getValue();
            // @formatter:off
            double p = Math.abs((nisP - curr.getPessimistic()) / (nisP - pisP));
            double l = Math.abs((nisM - curr.getMostLikely())  / (nisM - pisM));
            double o = Math.abs((nisO - curr.getOptimistic())  / (nisO - pisO));
            // @formatter:on

            retval.put(entry.getKey(), new FuzzyValue(p, l, o, getWeights()));
        }
        return retval;
    }

    protected void writeFuzzyFiles(Iterator<String> names, Stream<String> filenames, BoundsReader.SystemConfigFactory<C> factory) {
        List<BoundsReader<C>> files = filenames
                .map(f -> new BoundsReader<>(new File(srcDir, f), factory))
                .collect(Collectors.toList());
        try (AutoCloseable ignored = closeAll(files)) {
            List<BoundsReader<C>.BoundsSection> sections;
            while (names.hasNext()) {
                sections = files.stream()
                        .map(BoundsReader::nextSection)
                        .collect(Collectors.toList());
                if (sections.stream().anyMatch(Objects::isNull))
                    break;

                Map<C, FuzzyValue> map = normalize(parseSection(sections));
                try (PrintWriter writer = new PrintWriter(new File(outDir, String.format("%s-fuzzy-%04.2f-%04.2f-%04.2f.txt",
                        names.next(), getWeights().left, getWeights().middle, getWeights().right)))) {
                    for (Map.Entry<C, FuzzyValue> kv : map.entrySet().stream()
                            .sorted(Comparator.comparing(Map.Entry::getKey))
                            .collect(Collectors.toList())) {
                        for (String v : kv.getKey().getStringValues())
                            writer.printf("%2s ", v);
                        writer.printf("%8f (%8f,%8f,%8f)%n", kv.getValue().getMin(),
                                kv.getValue().getPessimistic(),
                                kv.getValue().getMostLikely(),
                                kv.getValue().getOptimistic());
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
