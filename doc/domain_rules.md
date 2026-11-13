# Regras de Domínio (Business Rules) - SIGEC

Estas regras regem a lógica de validação do sistema SIGEC e devem ser respeitadas em todas as implementações de reserva.

| ID | Regra | Descrição |
| :--- | :--- | :--- |
| **RD-01** | Limite de Reservas | Cada unidade residencial poderá possuir até duas reservas futuras simultaneamente. |
| **RD-02** | Antecedência (Salão) | O salão de festas poderá ser reservado somente com antecedência mínima de 48 horas. |
| **RD-03** | Conflito de Horário | Uma mesma unidade não poderá possuir duas reservas para o mesmo horário. |
| **RD-04** | Aprovação Mediada | Reservas do salão de festas e churrasqueira necessitam de aprovação do administrador. |
| **RD-05** | Prazo de Cancelamento | O morador poderá cancelar uma reserva com antecedência mínima de 24 horas. |
| **RD-06** | Vínculo de Unidade | A reserva deverá estar associada a uma unidade residencial. |
| **RD-07** | Horário de Funcionamento | O horário de funcionamento de cada espaço deverá ser respeitado. |
