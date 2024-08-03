function pos_plays = addition_outcome_detector(vec, pos_plays)
  
    if length(vec) <= 1
        return;
    end
    vecAUX = vec;
    if vecAUX(end) > vecAUX(end-1)
        vecAUX(end) = vecAUX(end) - vecAUX(end-1);
    elseif vecAUX(end) == vecAUX(end-1)
        pos_plays = pos_plays + 1;
    end
    vecAUX(end-1) = [];
    pos_plays = addition_outcome_detector(vecAUX, pos_plays);
    return;