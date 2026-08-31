if (!initialized) BladeStage1FeedbackInitialize(id);
age += 1;
if (age >= duration) instance_destroy();
