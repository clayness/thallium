package thallium.impl;

import com.fasterxml.jackson.databind.JsonNode;
import org.apache.commons.lang3.tuple.ImmutablePair;

import java.io.PrintWriter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

public abstract class GraphTrimmer<T extends SystemConfig> {

    protected abstract String formatOneTransition(T src, ImmutablePair<T, Boolean> pair, Function<T, Reward> rwdLookup);

    protected void printTransitions(PrintWriter writer, Function<String, T> cfgLookup, Function<T, Reward> rwdLookup,
                                    Iterator<Map.Entry<String, JsonNode>> fields) {
        StreamSupport.stream(Spliterators.spliteratorUnknownSize(fields, Spliterator.NONNULL), false)
                .sorted(Comparator.comparing(x -> cfgLookup.apply(x.getKey())))
                .forEachOrdered(x -> formatAllTransitions(cfgLookup, rwdLookup, x)
                    .forEachOrdered(writer::println));
    }

    private Stream<String> formatAllTransitions(Function<String, T> cfgLookup, Function<T, Reward> rwdLookup,
                                                Map.Entry<String, JsonNode> entry) {
        return trimSubOptimal(entry.getValue(), cfgLookup, rwdLookup).stream()
                .sorted(Comparator.comparing(ImmutablePair::getLeft))
                .map(p -> formatOneTransition(cfgLookup.apply(entry.getKey()), p, rwdLookup));
    }

    private List<ImmutablePair<T, Boolean>> trimSubOptimal(
            JsonNode graph, Function<String, T> lookup, Function<T, Reward> factory) {
        List<T> siblings = StreamSupport.stream(Spliterators.spliteratorUnknownSize(graph.fieldNames(), Spliterator.NONNULL),
                false)
                .map(lookup)
                .collect(Collectors.toList());
        return siblings.stream()
                .map(x -> this.testDomination(x, siblings.stream(), factory))
                .filter(Objects::nonNull)
                .collect(Collectors.toList());
    }

    private ImmutablePair<T, Boolean> testDomination(T src, Stream<T> siblings, Function<T, Reward> factory){
        Reward rwd = factory.apply(src);
        if (rwd == null)
            return ImmutablePair.of(src, false);
        return ImmutablePair.of(src, rwd.isDominated(siblings.map(factory)));
    }
}
