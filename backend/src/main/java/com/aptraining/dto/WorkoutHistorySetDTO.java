package com.aptraining.dto;

import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class WorkoutHistorySetDTO {

    private Integer setNumber;
    private Integer repetitions;
    private BigDecimal load;
}
