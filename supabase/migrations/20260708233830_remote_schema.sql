


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."delete_user_account"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
    DELETE FROM public.micro_actions WHERE action_plan_id IN (
      SELECT id FROM public.action_plans WHERE user_id = auth.uid()                                                                                    
    );                                                                                                                                                 
    DELETE FROM public.commitments WHERE user_id = auth.uid();                                                                                         
    DELETE FROM public.action_plans WHERE user_id = auth.uid();                                                                                        
    DELETE FROM public.swot_analyses WHERE transcription_id IN (                                                                                       
      SELECT id FROM public.transcriptions WHERE note_id IN (                                                                                          
        SELECT id FROM public.voice_notes WHERE user_id = auth.uid()                                                                                   
      )                                                                                                                                                
    );                                                                                                                                                 
    DELETE FROM public.transcriptions WHERE note_id IN (                                                                                            
      SELECT id FROM public.voice_notes WHERE user_id = auth.uid()                                                                                     
    );                                                                                                                                                 
    DELETE FROM public.voice_notes WHERE user_id = auth.uid();                                                                                         
    DELETE FROM auth.users WHERE id = auth.uid();                                                                                                      
  $$;


ALTER FUNCTION "public"."delete_user_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."action_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "analysis_id" "uuid" NOT NULL,
    "swot_item_id" "uuid" NOT NULL,
    "quadrant" "text" NOT NULL,
    "text" "text" NOT NULL,
    "time_estimate" "text",
    "is_completed" boolean DEFAULT false NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."action_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."action_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "analysis_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "summary" "text" NOT NULL,
    "total_estimate_minutes" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."action_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commitments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "micro_action_id" "uuid" NOT NULL,
    "scheduled_for" timestamp with time zone,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "commitments_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'completed'::"text", 'expired'::"text", 'skipped'::"text"])))
);


ALTER TABLE "public"."commitments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."micro_actions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "action_plan_id" "uuid" NOT NULL,
    "text" "text" NOT NULL,
    "done_criteria" "text" NOT NULL,
    "time_estimate_minutes" integer DEFAULT 15 NOT NULL,
    "priority" integer DEFAULT 1 NOT NULL,
    "quadrant" "text",
    "is_completed" boolean DEFAULT false NOT NULL,
    "completed_at" timestamp with time zone,
    "is_committed" boolean DEFAULT false NOT NULL,
    "committed_at" timestamp with time zone,
    "scheduled_for" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "template" "text",
    "action_type" "text",
    "deep_link_data" "jsonb",
    "completion_outcome" "text",
    "completion_note" "text"
);


ALTER TABLE "public"."micro_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."swot_analyses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transcription_id" "uuid",
    "strengths" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "weaknesses" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "opportunities" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "threats" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "summary" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "strength_items" "jsonb",
    "weakness_items" "jsonb",
    "opportunity_items" "jsonb",
    "threat_items" "jsonb",
    "viability_score" integer,
    "market_context" "text",
    "market_insights" "jsonb",
    "recommendations" "jsonb",
    "dimension_scores" "jsonb",
    "score_rationale" "text",
    "fatal_flaw" boolean,
    "idea_variants" "jsonb",
    CONSTRAINT "swot_analyses_viability_score_check" CHECK ((("viability_score" >= 0) AND ("viability_score" <= 100)))
);


ALTER TABLE "public"."swot_analyses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transcriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "note_id" "uuid",
    "text" "text" NOT NULL,
    "language" "text" DEFAULT 'en'::"text" NOT NULL,
    "confidence" numeric,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."transcriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."voice_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "title" "text" NOT NULL,
    "audio_file_url" "text" NOT NULL,
    "duration" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."voice_notes" OWNER TO "postgres";


ALTER TABLE ONLY "public"."action_items"
    ADD CONSTRAINT "action_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."action_plans"
    ADD CONSTRAINT "action_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."commitments"
    ADD CONSTRAINT "commitments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."micro_actions"
    ADD CONSTRAINT "micro_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."swot_analyses"
    ADD CONSTRAINT "swot_analyses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transcriptions"
    ADD CONSTRAINT "transcriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."voice_notes"
    ADD CONSTRAINT "voice_notes_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_action_plans_analysis" ON "public"."action_plans" USING "btree" ("analysis_id");



CREATE INDEX "idx_action_plans_user" ON "public"."action_plans" USING "btree" ("user_id");



CREATE INDEX "idx_commitments_user_active" ON "public"."commitments" USING "btree" ("user_id") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_micro_actions_plan" ON "public"."micro_actions" USING "btree" ("action_plan_id");



CREATE INDEX "idx_swot_analyses_transcription_id" ON "public"."swot_analyses" USING "btree" ("transcription_id");



CREATE INDEX "idx_transcriptions_note_id" ON "public"."transcriptions" USING "btree" ("note_id");



CREATE INDEX "idx_voice_notes_created_at" ON "public"."voice_notes" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_voice_notes_user_id" ON "public"."voice_notes" USING "btree" ("user_id");



ALTER TABLE ONLY "public"."action_items"
    ADD CONSTRAINT "action_items_analysis_id_fkey" FOREIGN KEY ("analysis_id") REFERENCES "public"."swot_analyses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."action_plans"
    ADD CONSTRAINT "action_plans_analysis_id_fkey" FOREIGN KEY ("analysis_id") REFERENCES "public"."swot_analyses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."action_plans"
    ADD CONSTRAINT "action_plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commitments"
    ADD CONSTRAINT "commitments_micro_action_id_fkey" FOREIGN KEY ("micro_action_id") REFERENCES "public"."micro_actions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commitments"
    ADD CONSTRAINT "commitments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."micro_actions"
    ADD CONSTRAINT "micro_actions_action_plan_id_fkey" FOREIGN KEY ("action_plan_id") REFERENCES "public"."action_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."swot_analyses"
    ADD CONSTRAINT "swot_analyses_transcription_id_fkey" FOREIGN KEY ("transcription_id") REFERENCES "public"."transcriptions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transcriptions"
    ADD CONSTRAINT "transcriptions_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "public"."voice_notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."voice_notes"
    ADD CONSTRAINT "voice_notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Users can delete own notes" ON "public"."voice_notes" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert analyses" ON "public"."swot_analyses" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."transcriptions" "t"
     JOIN "public"."voice_notes" "vn" ON (("vn"."id" = "t"."note_id")))
  WHERE (("t"."id" = "swot_analyses"."transcription_id") AND ("vn"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can insert own notes" ON "public"."voice_notes" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert transcriptions" ON "public"."transcriptions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."voice_notes"
  WHERE (("voice_notes"."id" = "transcriptions"."note_id") AND ("voice_notes"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can manage own action plans" ON "public"."action_plans" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own commitments" ON "public"."commitments" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own micro actions" ON "public"."micro_actions" USING (("action_plan_id" IN ( SELECT "action_plans"."id"
   FROM "public"."action_plans"
  WHERE ("action_plans"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can manage their own action items" ON "public"."action_items" USING (("analysis_id" IN ( SELECT "sa"."id"
   FROM (("public"."swot_analyses" "sa"
     JOIN "public"."transcriptions" "t" ON (("t"."id" = "sa"."transcription_id")))
     JOIN "public"."voice_notes" "vn" ON (("vn"."id" = "t"."note_id")))
  WHERE ("vn"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can update own notes" ON "public"."voice_notes" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update related transcriptions" ON "public"."transcriptions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."voice_notes"
  WHERE (("voice_notes"."id" = "transcriptions"."note_id") AND ("voice_notes"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."voice_notes"
  WHERE (("voice_notes"."id" = "transcriptions"."note_id") AND ("voice_notes"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view own notes" ON "public"."voice_notes" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view related analyses" ON "public"."swot_analyses" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."transcriptions" "t"
     JOIN "public"."voice_notes" "vn" ON (("vn"."id" = "t"."note_id")))
  WHERE (("t"."id" = "swot_analyses"."transcription_id") AND ("vn"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view related transcriptions" ON "public"."transcriptions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."voice_notes"
  WHERE (("voice_notes"."id" = "transcriptions"."note_id") AND ("voice_notes"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."action_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."action_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."commitments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."micro_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."swot_analyses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transcriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."voice_notes" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";


















GRANT ALL ON TABLE "public"."action_items" TO "anon";
GRANT ALL ON TABLE "public"."action_items" TO "authenticated";
GRANT ALL ON TABLE "public"."action_items" TO "service_role";



GRANT ALL ON TABLE "public"."action_plans" TO "anon";
GRANT ALL ON TABLE "public"."action_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."action_plans" TO "service_role";



GRANT ALL ON TABLE "public"."commitments" TO "anon";
GRANT ALL ON TABLE "public"."commitments" TO "authenticated";
GRANT ALL ON TABLE "public"."commitments" TO "service_role";



GRANT ALL ON TABLE "public"."micro_actions" TO "anon";
GRANT ALL ON TABLE "public"."micro_actions" TO "authenticated";
GRANT ALL ON TABLE "public"."micro_actions" TO "service_role";



GRANT ALL ON TABLE "public"."swot_analyses" TO "anon";
GRANT ALL ON TABLE "public"."swot_analyses" TO "authenticated";
GRANT ALL ON TABLE "public"."swot_analyses" TO "service_role";



GRANT ALL ON TABLE "public"."transcriptions" TO "anon";
GRANT ALL ON TABLE "public"."transcriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."transcriptions" TO "service_role";



GRANT ALL ON TABLE "public"."voice_notes" TO "anon";
GRANT ALL ON TABLE "public"."voice_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."voice_notes" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































drop extension if exists "pg_net";


  create policy "Users can delete own recordings"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'voice-recordings'::text) AND (lower((storage.foldername(name))[1]) = lower((auth.uid())::text))));



  create policy "Users can upload own recordings"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'voice-recordings'::text) AND (lower((storage.foldername(name))[1]) = lower((auth.uid())::text))));



  create policy "Users can view own recordings"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'voice-recordings'::text) AND (lower((storage.foldername(name))[1]) = lower((auth.uid())::text))));



