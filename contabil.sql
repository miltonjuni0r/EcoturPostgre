-- ============================================================
-- EcoTurismo - Schema contabil
-- PostgreSQL
--
-- ============================================================

-- 1. Schema e tipo de pagamento
CREATE SCHEMA IF NOT EXISTS contabil;

CREATE TYPE contabil.forma AS ENUM (
    'PIX',
    'BOLETO',
    'CARTAO',
    'A_VISTA'
);

-- 2. Sequência usada para gerar os IDs dos pagamentos
CREATE SEQUENCE contabil.pagamentos_id_pagamentos_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- 3. Tabela de pagamentos
CREATE TABLE contabil.pagamentos (
    id_pagamentos integer NOT NULL
        DEFAULT nextval('contabil.pagamentos_id_pagamentos_seq'::regclass),
    data_pagamento date NOT NULL,
    forma contabil.forma,
    id_reserva integer NOT NULL,

    CONSTRAINT pagamentos_pkey
        PRIMARY KEY (id_pagamentos),

    CONSTRAINT fk_pagamento_reserva
        FOREIGN KEY (id_reserva)
        REFERENCES site.reservas (id_reserva)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

ALTER SEQUENCE contabil.pagamentos_id_pagamentos_seq
    OWNED BY contabil.pagamentos.id_pagamentos;

-- 4. View do relatório financeiro
CREATE OR REPLACE VIEW contabil.vw_relatorio_financeiro AS
SELECT
    p.id_pagamentos,
    p.data_pagamento,
    p.forma,
    r.status AS status_reserva,
    pac.preco AS valor_recebido
FROM contabil.pagamentos AS p
INNER JOIN site.reservas AS r
    ON p.id_reserva = r.id_reserva
INNER JOIN site.pacotes AS pac
    ON r.fk_local = pac.id_pacotes;

-- 5. Função para validar o pagamento
-- Impede inserir ou transferir um pagamento para uma reserva cancelada.
CREATE OR REPLACE FUNCTION contabil.fn_validar_pagamento_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_reserva VARCHAR(255);
BEGIN
    SELECT status
      INTO v_status_reserva
      FROM site.reservas
     WHERE id_reserva = NEW.id_reserva;

    IF v_status_reserva = 'Cancelada' THEN
        RAISE EXCEPTION
            'Não é possível registrar ou transferir um pagamento para a reserva % porque ela está cancelada.',
            NEW.id_reserva;
    END IF;

    RETURN NEW;
END;
$$;

-- 6. Trigger de validação, antes de inserir ou trocar a reserva do pagamento
DROP TRIGGER IF EXISTS trg_validar_pagamento_reserva
    ON contabil.pagamentos;

CREATE TRIGGER trg_validar_pagamento_reserva
BEFORE INSERT OR UPDATE OF id_reserva
