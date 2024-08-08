CREATE TABLE IF NOT EXISTS stock (
    id SERIAL PRIMARY KEY,
    product VARCHAR(255),
    unit VARCHAR(50),
    amount NUMERIC(10, 2),
    price NUMERIC(10, 2)
);
INSERT INTO stock(product,unit,amount,price) VALUES ('z80','unit',100,2);
INSERT INTO stock(product,unit,amount,price) VALUES ('6502','unit',100,2);
INSERT INTO stock(product,unit,amount,price) VALUES ('m68k','unit',100,2);
INSERT INTO stock(product,unit,amount,price) VALUES ('8086','unit',100.0,5);
INSERT INTO stock(product,unit,amount,price) VALUES ('Pentium','unit',100.0,5);