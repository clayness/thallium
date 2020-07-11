package thallium.impl.dart;

import thallium.impl.Reward;

import java.util.stream.Stream;

public class DartReward extends Reward {

    final double detected;
    final double distance;

    DartReward(double detected, double distance) {
        this.detected = detected;
        this.distance = distance;
    }

    @Override
    public boolean isDominated(Stream<? extends Reward> others) {
        return others.filter(DartReward.class::isInstance)
                .map(DartReward.class::cast)
                .anyMatch(this::isDominatedBy);
    }

    private boolean isDominatedBy(DartReward other) {
        if (detected < other.detected)
            return (distance <= other.distance);
        if (distance < other.distance)
            return (detected <= other.detected);
        return false;
    }
}
