package thallium.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.MappingIterator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import org.apache.commons.lang3.tuple.ImmutablePair;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Array;
import java.util.stream.StreamSupport;

public class ConfigReader {
    public static <T> ImmutablePair<T[], ObjectNode> readConfigFile(final File yaml, final Class<T> clazz) throws IOException {
        YAMLFactory factory = new YAMLFactory();
        ObjectMapper mapper = new ObjectMapper(factory);
        MappingIterator<ObjectNode> iterator = mapper.readValues(factory.createParser(yaml),
                new TypeReference<ObjectNode>() {
                });

        @SuppressWarnings("unchecked")
        T[] configs = StreamSupport.stream(iterator.next().get("configs").spliterator(), false)
                .map(x -> mapper.convertValue(x, clazz))
                .toArray(i -> (T[]) Array.newInstance(clazz, i));
        ObjectNode edges = iterator.next();
        return new ImmutablePair<>(configs, edges);
    }
}
