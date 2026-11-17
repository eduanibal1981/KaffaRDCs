begin read only;
select set_config('request.jwt.claim.sub',(select id::text from auth.users where lower(email)='bausheraud@kafaa.omanrdcs.com'),true);
set local role authenticated;
select public.validate_assessment_submission('3c0c9f1a-fdfb-42f9-8f2c-ce92c6ac474b') preflight;
rollback;
